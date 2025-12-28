import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Uygulama genelinde kullanılan environment değişkenlerine erişim sağlar
class EnvConfig {
  // Private constructor
  EnvConfig._();

  /// Demo modu - WebSocket ve BLE olmadan çalışır
  static bool get demoMode =>
      dotenv.env['DEMO_MODE']?.toLowerCase() == 'true';

  /// WebSocket sunucu URL'i
  static String get websocketUrl =>
      dotenv.env['WEBSOCKET_URL'] ?? 'ws://localhost:8080/ws/navigation';

  /// WebSocket yeniden bağlanma süresi (ms)
  static int get websocketReconnectInterval =>
      int.tryParse(dotenv.env['WEBSOCKET_RECONNECT_INTERVAL'] ?? '5000') ?? 5000;

  /// Beacon MAC adresi prefix'i (filtreleme için)
  static String get beaconMacPrefix =>
      dotenv.env['BEACON_MAC_PREFIX'] ?? '08:92:72:87';

  /// BLE tarama süresi (ms)
  static int get bleScanDuration =>
      int.tryParse(dotenv.env['BLE_SCAN_DURATION'] ?? '2000') ?? 2000;

  /// BLE tarama aralığı (ms)
  static int get bleScanInterval =>
      int.tryParse(dotenv.env['BLE_SCAN_INTERVAL'] ?? '1000') ?? 1000;

  /// Minimum RSSI eşik değeri
  static int get minRssiThreshold =>
      int.tryParse(dotenv.env['MIN_RSSI_THRESHOLD'] ?? '-90') ?? -90;

  /// Seçilecek en güçlü beacon sayısı
  static int get topBeaconsCount =>
      int.tryParse(dotenv.env['TOP_BEACONS_COUNT'] ?? '3') ?? 3;

  /// Debug modu
  static bool get debugMode =>
      dotenv.env['DEBUG_MODE']?.toLowerCase() == 'true';
}
