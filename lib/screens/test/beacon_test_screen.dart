import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../core/theme/app_theme.dart';
import '../../core/config/env_config.dart';

/// Beacon Test Ekranı
/// Gerçek BLE beacon'ları tarar ve RSSI'ya göre sıralar
class BeaconTestScreen extends StatefulWidget {
  const BeaconTestScreen({super.key});

  @override
  State<BeaconTestScreen> createState() => _BeaconTestScreenState();
}

class _BeaconTestScreenState extends State<BeaconTestScreen> {
  /// Bulunan beacon'lar (MAC -> Beacon bilgisi)
  final Map<String, _BeaconInfo> _beacons = {};
  
  /// Tarama durumu
  bool _isScanning = false;
  
  /// Bluetooth durumu
  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;
  
  /// Subscription'lar
  StreamSubscription<BluetoothAdapterState>? _adapterStateSubscription;
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  
  /// Son güncelleme zamanı
  DateTime? _lastUpdate;

  @override
  void initState() {
    super.initState();
    _initBluetooth();
  }

  @override
  void dispose() {
    _stopScanning();
    _adapterStateSubscription?.cancel();
    _scanSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initBluetooth() async {
    // Bluetooth durumunu dinle
    _adapterStateSubscription = FlutterBluePlus.adapterState.listen((state) {
      setState(() => _adapterState = state);
      if (state == BluetoothAdapterState.on) {
        _startScanning();
      }
    });
  }

  Future<void> _startScanning() async {
    if (_isScanning) return;
    
    setState(() {
      _isScanning = true;
      _beacons.clear();
    });

    try {
      // Taramayı başlat
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 30),
        androidScanMode: AndroidScanMode.lowLatency,
      );

      // Sonuçları dinle
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (var result in results) {
          final device = result.device;
          final macAddress = device.remoteId.str.toUpperCase();
          
          // Sadece bizim beacon prefix'imize sahip olanları filtrele (opsiyonel)
          // Tüm cihazları görmek için bu kontrolü kaldırabilirsiniz
          final isOurBeacon = macAddress.startsWith(EnvConfig.beaconMacPrefix);
          
          setState(() {
            _beacons[macAddress] = _BeaconInfo(
              macAddress: macAddress,
              name: device.platformName.isNotEmpty ? device.platformName : 'Unknown',
              rssi: result.rssi,
              lastSeen: DateTime.now(),
              isOurBeacon: isOurBeacon,
              advertisementData: result.advertisementData,
            );
            _lastUpdate = DateTime.now();
          });
        }
      });
    } catch (e) {
      debugPrint('Tarama hatası: $e');
      setState(() => _isScanning = false);
    }
  }

  Future<void> _stopScanning() async {
    await FlutterBluePlus.stopScan();
    setState(() => _isScanning = false);
  }

  void _toggleScanning() {
    if (_isScanning) {
      _stopScanning();
    } else {
      _startScanning();
    }
  }

  void _clearBeacons() {
    setState(() {
      _beacons.clear();
      _lastUpdate = null;
    });
  }

  /// RSSI'ya göre sıralanmış beacon listesi (en güçlü en üstte)
  List<_BeaconInfo> get _sortedBeacons {
    final list = _beacons.values.toList();
    list.sort((a, b) => b.rssi.compareTo(a.rssi)); // Büyükten küçüğe (en güçlü üstte)
    return list;
  }

  /// Sadece bizim beacon'larımız
  List<_BeaconInfo> get _ourBeacons {
    return _sortedBeacons.where((b) => b.isOurBeacon).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Beacon Test'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _clearBeacons,
            tooltip: 'Listeyi Temizle',
          ),
        ],
      ),
      body: Column(
        children: [
          // Durum kartı
          _buildStatusCard(),
          
          // İstatistikler
          _buildStatsCard(),
          
          // Beacon listesi
          Expanded(
            child: _buildBeaconList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _toggleScanning,
        icon: Icon(_isScanning ? Icons.stop : Icons.bluetooth_searching),
        label: Text(_isScanning ? 'Durdur' : 'Tara'),
        backgroundColor: _isScanning ? AppColors.error : AppColors.primary,
      ),
    );
  }

  Widget _buildStatusCard() {
    final isBluetoothOn = _adapterState == BluetoothAdapterState.on;
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isBluetoothOn ? AppColors.success.withOpacity(0.1) : AppColors.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isBluetoothOn ? AppColors.success : AppColors.error,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isBluetoothOn ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
            color: isBluetoothOn ? AppColors.success : AppColors.error,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isBluetoothOn ? 'Bluetooth Açık' : 'Bluetooth Kapalı',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isBluetoothOn ? AppColors.success : AppColors.error,
                  ),
                ),
                Text(
                  _isScanning ? 'Tarama devam ediyor...' : 'Tarama beklemede',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (_isScanning)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            'Toplam Cihaz',
            _beacons.length.toString(),
            Icons.devices,
            AppColors.primary,
          ),
          _buildStatItem(
            'Bizim Beacon',
            _ourBeacons.length.toString(),
            Icons.cell_tower,
            AppColors.success,
          ),
          _buildStatItem(
            'Prefix',
            EnvConfig.beaconMacPrefix,
            Icons.tag,
            AppColors.warning,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildBeaconList() {
    final beacons = _sortedBeacons;
    
    if (beacons.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bluetooth_searching,
              size: 64,
              color: AppColors.textHint,
            ),
            const SizedBox(height: 16),
            Text(
              _isScanning ? 'Beacon aranıyor...' : 'Taramayı başlatın',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: beacons.length,
      itemBuilder: (context, index) {
        final beacon = beacons[index];
        return _buildBeaconCard(beacon, index + 1);
      },
    );
  }

  Widget _buildBeaconCard(_BeaconInfo beacon, int rank) {
    final rssiColor = _getRssiColor(beacon.rssi);
    final signalStrength = _getSignalStrength(beacon.rssi);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: beacon.isOurBeacon 
            ? AppColors.primary.withOpacity(0.05) 
            : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: beacon.isOurBeacon 
              ? AppColors.primary.withOpacity(0.3) 
              : Colors.grey.withOpacity(0.2),
          width: beacon.isOurBeacon ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        children: [
          // Sıralama
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: rank <= 3 ? rssiColor.withOpacity(0.2) : Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '#$rank',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: rank <= 3 ? rssiColor : AppColors.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          
          // Beacon bilgileri
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (beacon.isOurBeacon)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'BİZİM',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    Expanded(
                      child: Text(
                        beacon.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  beacon.macAddress,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 12, color: AppColors.textHint),
                    const SizedBox(width: 4),
                    Text(
                      _formatTime(beacon.lastSeen),
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textHint,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // RSSI göstergesi
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  Icon(
                    _getSignalIcon(beacon.rssi),
                    color: rssiColor,
                    size: 20,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${beacon.rssi} dBm',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: rssiColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                signalStrength,
                style: TextStyle(
                  fontSize: 11,
                  color: rssiColor,
                ),
              ),
              const SizedBox(height: 4),
              // Sinyal çubuğu
              _buildSignalBar(beacon.rssi),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSignalBar(int rssi) {
    // -30 (en iyi) ile -100 (en kötü) arasında normalize et
    final normalized = ((rssi + 100) / 70).clamp(0.0, 1.0);
    
    return Container(
      width: 60,
      height: 6,
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.2),
        borderRadius: BorderRadius.circular(3),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: normalized,
        child: Container(
          decoration: BoxDecoration(
            color: _getRssiColor(rssi),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }

  Color _getRssiColor(int rssi) {
    if (rssi >= -50) return AppColors.success;
    if (rssi >= -70) return AppColors.warning;
    return AppColors.error;
  }

  String _getSignalStrength(int rssi) {
    if (rssi >= -50) return 'Mükemmel';
    if (rssi >= -60) return 'Çok İyi';
    if (rssi >= -70) return 'İyi';
    if (rssi >= -80) return 'Orta';
    if (rssi >= -90) return 'Zayıf';
    return 'Çok Zayıf';
  }

  IconData _getSignalIcon(int rssi) {
    if (rssi >= -50) return Icons.signal_cellular_4_bar;
    if (rssi >= -60) return Icons.signal_cellular_4_bar;
    if (rssi >= -70) return Icons.network_cell;
    if (rssi >= -80) return Icons.signal_cellular_connected_no_internet_4_bar;
    return Icons.signal_cellular_0_bar;
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    
    if (diff.inSeconds < 5) return 'Şimdi';
    if (diff.inSeconds < 60) return '${diff.inSeconds} sn önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
    return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
  }
}

/// Beacon bilgi modeli
class _BeaconInfo {
  final String macAddress;
  final String name;
  final int rssi;
  final DateTime lastSeen;
  final bool isOurBeacon;
  final AdvertisementData advertisementData;

  _BeaconInfo({
    required this.macAddress,
    required this.name,
    required this.rssi,
    required this.lastSeen,
    required this.isOurBeacon,
    required this.advertisementData,
  });
}
