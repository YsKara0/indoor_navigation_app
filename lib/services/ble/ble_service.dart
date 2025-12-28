import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/config/env_config.dart';
import '../../models/models.dart';

/// BLE tarama durumu
enum BleScanState {
  idle,
  scanning,
  stopped,
  error,
  bluetoothOff,
  noPermission,
}

/// BLE Scanner Service
/// ESP32-C3 beacon cihazlarından sinyal toplar
class BleService extends ChangeNotifier {
  /// Tarama durumu
  BleScanState _scanState = BleScanState.idle;
  BleScanState get scanState => _scanState;

  /// Bulunan beacon'lar (MAC adresi -> Beacon)
  final Map<String, BeaconModel> _beacons = {};
  List<BeaconModel> get beacons => _beacons.values.toList();

  /// En güçlü beacon'lar
  List<BeaconModel> get topBeacons {
    final sorted = List<BeaconModel>.from(_beacons.values)
      ..sort((a, b) => b.rssi.compareTo(a.rssi));
    return sorted.take(EnvConfig.topBeaconsCount).toList();
  }

  /// Tarama subscription
  StreamSubscription<List<ScanResult>>? _scanSubscription;

  /// Periyodik tarama timer
  Timer? _scanTimer;

  /// Son hata mesajı
  String? _lastError;
  String? get lastError => _lastError;

  /// Callback: Yeni beacon verisi geldiğinde
  Function(List<BeaconModel>)? onBeaconsUpdated;

  /// Debug modu
  bool get _isDebug => EnvConfig.debugMode;

  /// MAC prefix filtresi
  String get _macPrefix => EnvConfig.beaconMacPrefix;

  /// Servisi başlat
  Future<bool> initialize() async {
    _log('BLE servis başlatılıyor...');

    // Bluetooth durumunu kontrol et
    final isSupported = await FlutterBluePlus.isSupported;
    if (!isSupported) {
      _lastError = 'Bu cihaz Bluetooth desteklemiyor';
      _scanState = BleScanState.error;
      notifyListeners();
      return false;
    }

    // İzinleri kontrol et
    final hasPermission = await _checkPermissions();
    if (!hasPermission) {
      _scanState = BleScanState.noPermission;
      notifyListeners();
      return false;
    }

    // Bluetooth açık mı kontrol et
    final adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      _lastError = 'Bluetooth kapalı';
      _scanState = BleScanState.bluetoothOff;
      notifyListeners();
      return false;
    }

    // Bluetooth durum değişikliklerini dinle
    FlutterBluePlus.adapterState.listen((state) {
      if (state == BluetoothAdapterState.off) {
        _scanState = BleScanState.bluetoothOff;
        stopScanning();
        notifyListeners();
      }
    });

    _log('BLE servis hazır');
    return true;
  }

  /// İzinleri kontrol et ve iste
  Future<bool> _checkPermissions() async {
    _log('İzinler kontrol ediliyor...');

    // Android için gerekli izinler
    final permissions = [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ];

    for (final permission in permissions) {
      final status = await permission.status;
      if (!status.isGranted) {
        final result = await permission.request();
        if (!result.isGranted) {
          _lastError = 'Bluetooth izni verilmedi';
          return false;
        }
      }
    }

    _log('Tüm izinler verildi');
    return true;
  }

  /// Taramayı başlat
  Future<void> startScanning() async {
    if (_scanState == BleScanState.scanning) {
      _log('Zaten taranıyor');
      return;
    }

    _log('BLE taraması başlatılıyor...');

    try {
      // Önceki taramayı durdur
      await FlutterBluePlus.stopScan();

      _scanState = BleScanState.scanning;
      notifyListeners();

      // Tarama sonuçlarını dinle
      _scanSubscription = FlutterBluePlus.scanResults.listen(
        _onScanResults,
        onError: (error) {
          _log('Tarama hatası: $error', isError: true);
          _lastError = error.toString();
          _scanState = BleScanState.error;
          notifyListeners();
        },
      );

      // Periyodik tarama başlat
      _startPeriodicScan();
    } catch (e) {
      _log('Tarama başlatma hatası: $e', isError: true);
      _lastError = e.toString();
      _scanState = BleScanState.error;
      notifyListeners();
    }
  }

  /// Periyodik tarama
  void _startPeriodicScan() {
    _scanTimer?.cancel();

    // İlk taramayı başlat
    _performScan();

    // Periyodik tarama
    _scanTimer = Timer.periodic(
      Duration(milliseconds: EnvConfig.bleScanInterval + EnvConfig.bleScanDuration),
      (_) => _performScan(),
    );
  }

  /// Tek bir tarama döngüsü
  Future<void> _performScan() async {
    if (_scanState != BleScanState.scanning) return;

    try {
      await FlutterBluePlus.startScan(
        timeout: Duration(milliseconds: EnvConfig.bleScanDuration),
        androidUsesFineLocation: true,
      );
    } catch (e) {
      _log('Tarama hatası: $e', isError: true);
    }
  }

  /// Tarama sonuçlarını işle
  void _onScanResults(List<ScanResult> results) {
    final now = DateTime.now();
    bool hasNewData = false;

    for (final result in results) {
      final macAddress = result.device.remoteId.str;

      // MAC prefix filtresi
      if (!_matchesMacPrefix(macAddress)) {
        continue;
      }

      // Minimum RSSI filtresi
      if (result.rssi < EnvConfig.minRssiThreshold) {
        continue;
      }

      // Beacon modelini oluştur veya güncelle
      final beacon = BeaconModel(
        macAddress: macAddress,
        name: result.device.platformName.isNotEmpty
            ? result.device.platformName
            : 'ESP32-Beacon',
        rssi: result.rssi,
        lastSeen: now,
      );

      _beacons[macAddress] = beacon;
      hasNewData = true;

      _log('Beacon bulundu: $macAddress (RSSI: ${result.rssi})');
    }

    // Eski beacon'ları temizle (5 saniyeden eski)
    _cleanOldBeacons();

    if (hasNewData) {
      notifyListeners();

      // Callback'i çağır
      if (onBeaconsUpdated != null && _beacons.isNotEmpty) {
        onBeaconsUpdated!(topBeacons);
      }
    }
  }

  /// MAC prefix kontrolü
  bool _matchesMacPrefix(String macAddress) {
    if (_macPrefix.isEmpty) return true;

    // Büyük-küçük harf duyarsız karşılaştırma
    return macAddress.toUpperCase().startsWith(_macPrefix.toUpperCase());
  }

  /// Eski beacon'ları temizle
  void _cleanOldBeacons() {
    final now = DateTime.now();
    final threshold = const Duration(seconds: 5);

    _beacons.removeWhere((_, beacon) {
      return now.difference(beacon.lastSeen) > threshold;
    });
  }

  /// Taramayı durdur
  Future<void> stopScanning() async {
    _log('BLE taraması durduruluyor...');

    _scanTimer?.cancel();
    _scanTimer = null;

    await _scanSubscription?.cancel();
    _scanSubscription = null;

    await FlutterBluePlus.stopScan();

    _scanState = BleScanState.stopped;
    notifyListeners();

    _log('BLE taraması durduruldu');
  }

  /// Beacon listesini temizle
  void clearBeacons() {
    _beacons.clear();
    notifyListeners();
  }

  /// Bluetooth'u aç (Android)
  Future<void> turnOnBluetooth() async {
    try {
      await FlutterBluePlus.turnOn();
    } catch (e) {
      _log('Bluetooth açma hatası: $e', isError: true);
    }
  }

  /// Log yazdır
  void _log(String message, {bool isError = false}) {
    if (_isDebug) {
      final prefix = isError ? '❌ [BLE ERROR]' : '📶 [BLE]';
      debugPrint('$prefix $message');
    }
  }

  @override
  void dispose() {
    stopScanning();
    super.dispose();
  }
}
