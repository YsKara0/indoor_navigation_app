import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../core/config/env_config.dart';
import '../../models/models.dart';
import 'websocket_helper.dart';

/// WebSocket servis durumu
enum WebSocketServiceState {
  idle,
  scanning,
  navigating,
  error,
}

/// WebSocket Service
/// BLE verileri ile WebSocket arasındaki köprüyü sağlar
class WebSocketService extends ChangeNotifier {
  final WebSocketHelper _wsHelper = WebSocketHelper();

  /// Servis durumu
  WebSocketServiceState _state = WebSocketServiceState.idle;
  WebSocketServiceState get state => _state;

  /// Bağlantı durumu
  WebSocketConnectionState get connectionState => _wsHelper.connectionState;

  /// Mevcut kullanıcı konumu
  UserLocation? _currentLocation;
  UserLocation? get currentLocation => _currentLocation;

  /// Aktif navigasyon rotası
  NavigationRoute? _activeRoute;
  NavigationRoute? get activeRoute => _activeRoute;

  /// Son hata mesajı
  String? _lastError;
  String? get lastError => _lastError;

  /// Subscriptions
  final List<StreamSubscription> _subscriptions = [];

  /// Debug modu
  bool get _isDebug => EnvConfig.debugMode;

  /// Servisi başlat
  Future<void> initialize() async {
    _log('WebSocket servis başlatılıyor...');

    // Bağlantı durumu dinle
    _subscriptions.add(
      _wsHelper.connectionStateStream.listen(_onConnectionStateChanged),
    );

    // Konum güncellemelerini dinle
    _subscriptions.add(
      _wsHelper.locationStream.listen(_onLocationUpdate),
    );

    // Navigasyon güncellemelerini dinle
    _subscriptions.add(
      _wsHelper.navigationStream.listen(_onNavigationUpdate),
    );

    // Bağlantıyı başlat
    await connect();
  }

  /// WebSocket'e bağlan
  Future<bool> connect() async {
    final success = await _wsHelper.connect();
    if (!success) {
      _lastError = 'WebSocket bağlantısı kurulamadı';
      notifyListeners();
    }
    return success;
  }

  /// Bağlantıyı kes
  Future<void> disconnect() async {
    await _wsHelper.disconnect();
  }

  /// Beacon verilerini gönder
  void sendBeaconData(List<BeaconModel> beacons) {
    if (beacons.isEmpty) return;

    // En güçlü N beacon'ı seç
    final topBeacons = _selectTopBeacons(beacons);

    if (topBeacons.isNotEmpty) {
      _wsHelper.sendBeaconData(topBeacons);
      _state = WebSocketServiceState.scanning;
      notifyListeners();
    }
  }

  /// En güçlü beacon'ları seç
  List<BeaconModel> _selectTopBeacons(List<BeaconModel> beacons) {
    // RSSI'ya göre sırala (büyükten küçüğe, çünkü -30 > -70)
    final sorted = List<BeaconModel>.from(beacons)
      ..sort((a, b) => b.rssi.compareTo(a.rssi));

    // Minimum RSSI eşiğini geçenleri filtrele
    final filtered = sorted
        .where((b) => b.rssi >= EnvConfig.minRssiThreshold)
        .toList();

    // En fazla N tane al
    return filtered.take(EnvConfig.topBeaconsCount).toList();
  }

  /// Navigasyon başlat
  void startNavigation(String destinationId) {
    _log('Navigasyon başlatılıyor: $destinationId');
    _state = WebSocketServiceState.navigating;
    _wsHelper.requestNavigation(destinationId);
    notifyListeners();
  }

  /// Navigasyonu iptal et
  void cancelNavigation() {
    _log('Navigasyon iptal ediliyor');
    _wsHelper.cancelNavigation();
    _activeRoute = null;
    _state = WebSocketServiceState.scanning;
    notifyListeners();
  }

  /// Bağlantı durumu değişikliği
  void _onConnectionStateChanged(WebSocketConnectionState state) {
    _log('Bağlantı durumu: $state');

    if (state == WebSocketConnectionState.error) {
      _lastError = 'Bağlantı hatası';
      _state = WebSocketServiceState.error;
    } else if (state == WebSocketConnectionState.connected) {
      _lastError = null;
      if (_state == WebSocketServiceState.error) {
        _state = WebSocketServiceState.idle;
      }
    }

    notifyListeners();
  }

  /// Konum güncellemesi alındığında
  void _onLocationUpdate(UserLocation location) {
    _currentLocation = location;
    _log('Konum güncellendi: ${location.position}');

    // Hedefe ulaşıldı mı kontrol et
    if (_activeRoute != null) {
      final distanceToDestination = location.position.distanceTo(_activeRoute!.destination);
      if (distanceToDestination <= 2.0) {
        // 2 metre içinde
        _log('Hedefe ulaşıldı!');
        // TODO: Hedefe ulaşıldı bildirimi
      }
    }

    notifyListeners();
  }

  /// Navigasyon güncellemesi alındığında
  void _onNavigationUpdate(NavigationRoute? route) {
    _activeRoute = route;

    if (route != null) {
      _log('Rota alındı: ${route.destinationName}');
      _state = WebSocketServiceState.navigating;
    } else {
      _state = WebSocketServiceState.scanning;
    }

    notifyListeners();
  }

  /// Log yazdır
  void _log(String message) {
    if (_isDebug) {
      debugPrint('📡 [WS Service] $message');
    }
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _wsHelper.dispose();
    super.dispose();
  }
}
