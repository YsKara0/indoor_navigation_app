import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../core/config/env_config.dart';
import '../../core/constants/app_constants.dart';
import '../../models/models.dart';

/// WebSocket bağlantı durumları
enum WebSocketConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

/// WebSocket mesaj tipi
enum WebSocketMessageType {
  locationUpdate,
  beaconData,
  navigationPath,
  requestNavigation,
  cancelNavigation,
  ping,
  pong,
  error,
}

/// Backend'den gelen mesaj yapısı
class WebSocketMessage {
  final WebSocketMessageType type;
  final Map<String, dynamic>? data;
  final String? error;
  final DateTime timestamp;

  WebSocketMessage({
    required this.type,
    this.data,
    this.error,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory WebSocketMessage.fromJson(Map<String, dynamic> json) {
    return WebSocketMessage(
      type: _parseMessageType(json['type'] as String?),
      data: json['data'] as Map<String, dynamic>?,
      error: json['error'] as String?,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name.toUpperCase(),
      if (data != null) 'data': data,
      if (error != null) 'error': error,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  static WebSocketMessageType _parseMessageType(String? type) {
    switch (type?.toUpperCase()) {
      case 'LOCATION_UPDATE':
        return WebSocketMessageType.locationUpdate;
      case 'BEACON_DATA':
        return WebSocketMessageType.beaconData;
      case 'NAVIGATION_PATH':
        return WebSocketMessageType.navigationPath;
      case 'REQUEST_NAVIGATION':
        return WebSocketMessageType.requestNavigation;
      case 'CANCEL_NAVIGATION':
        return WebSocketMessageType.cancelNavigation;
      case 'PING':
        return WebSocketMessageType.ping;
      case 'PONG':
        return WebSocketMessageType.pong;
      case 'ERROR':
        return WebSocketMessageType.error;
      default:
        return WebSocketMessageType.error;
    }
  }
}

/// WebSocket yardımcı servisi
/// Backend ile gerçek zamanlı iletişimi yönetir
class WebSocketHelper {
  // Singleton pattern
  static final WebSocketHelper _instance = WebSocketHelper._internal();
  factory WebSocketHelper() => _instance;
  WebSocketHelper._internal();

  /// WebSocket channel
  WebSocketChannel? _channel;

  /// Bağlantı durumu
  WebSocketConnectionState _connectionState = WebSocketConnectionState.disconnected;
  WebSocketConnectionState get connectionState => _connectionState;

  /// Bağlantı durumu stream controller
  final _connectionStateController = StreamController<WebSocketConnectionState>.broadcast();
  Stream<WebSocketConnectionState> get connectionStateStream => _connectionStateController.stream;

  /// Gelen mesajlar için stream controller
  final _messageController = StreamController<WebSocketMessage>.broadcast();
  Stream<WebSocketMessage> get messageStream => _messageController.stream;

  /// Konum güncellemeleri için stream
  final _locationController = StreamController<UserLocation>.broadcast();
  Stream<UserLocation> get locationStream => _locationController.stream;

  /// Navigasyon rotası için stream
  final _navigationController = StreamController<NavigationRoute?>.broadcast();
  Stream<NavigationRoute?> get navigationStream => _navigationController.stream;

  /// Otomatik yeniden bağlanma
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 10;

  /// Ping/Pong için heartbeat timer
  Timer? _heartbeatTimer;
  DateTime? _lastPongReceived;

  /// Debug modu
  bool get _isDebug => EnvConfig.debugMode;

  /// Bağlantıyı başlat
  Future<bool> connect({String? customUrl}) async {
    if (_connectionState == WebSocketConnectionState.connected) {
      _log('Zaten bağlı');
      return true;
    }

    _updateConnectionState(WebSocketConnectionState.connecting);
    _log('WebSocket bağlantısı başlatılıyor...');

    try {
      final url = customUrl ?? EnvConfig.websocketUrl;
      _channel = WebSocketChannel.connect(Uri.parse(url));

      // Bağlantının kurulmasını bekle
      await _channel!.ready;

      _log('WebSocket bağlantısı başarılı: $url');
      _updateConnectionState(WebSocketConnectionState.connected);
      _reconnectAttempts = 0;

      // Mesajları dinle
      _listenToMessages();

      // Heartbeat başlat
      _startHeartbeat();

      return true;
    } catch (e) {
      _log('WebSocket bağlantı hatası: $e', isError: true);
      _updateConnectionState(WebSocketConnectionState.error);
      _scheduleReconnect();
      return false;
    }
  }

  /// Bağlantıyı kapat
  Future<void> disconnect() async {
    _log('WebSocket bağlantısı kapatılıyor...');

    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();

    await _channel?.sink.close();
    _channel = null;

    _updateConnectionState(WebSocketConnectionState.disconnected);
    _log('WebSocket bağlantısı kapatıldı');
  }

  /// Mesajları dinle
  void _listenToMessages() {
    _channel?.stream.listen(
      (dynamic data) {
        try {
          final jsonData = jsonDecode(data as String) as Map<String, dynamic>;
          final message = WebSocketMessage.fromJson(jsonData);

          _log('Mesaj alındı: ${message.type}');
          _messageController.add(message);

          // Mesaj tipine göre işle
          _handleMessage(message);
        } catch (e) {
          _log('Mesaj parse hatası: $e', isError: true);
        }
      },
      onError: (error) {
        _log('WebSocket stream hatası: $error', isError: true);
        _updateConnectionState(WebSocketConnectionState.error);
        _scheduleReconnect();
      },
      onDone: () {
        _log('WebSocket bağlantısı kapandı');
        _updateConnectionState(WebSocketConnectionState.disconnected);
        _scheduleReconnect();
      },
    );
  }

  /// Mesaj tipine göre işle
  void _handleMessage(WebSocketMessage message) {
    switch (message.type) {
      case WebSocketMessageType.locationUpdate:
        if (message.data != null) {
          final location = UserLocation.fromJson(message.data!);
          _locationController.add(location);
        }
        break;

      case WebSocketMessageType.navigationPath:
        if (message.data != null) {
          final route = NavigationRoute.fromJson(message.data!);
          _navigationController.add(route);
        } else {
          _navigationController.add(null);
        }
        break;

      case WebSocketMessageType.pong:
        _lastPongReceived = DateTime.now();
        break;

      case WebSocketMessageType.error:
        _log('Backend hatası: ${message.error}', isError: true);
        break;

      default:
        break;
    }
  }

  /// Beacon verilerini gönder
  void sendBeaconData(List<BeaconModel> beacons) {
    if (_connectionState != WebSocketConnectionState.connected) {
      _log('Bağlantı yok, beacon verisi gönderilemedi', isError: true);
      return;
    }

    final message = WebSocketMessage(
      type: WebSocketMessageType.beaconData,
      data: {
        'beacons': beacons.map((b) => b.toJson()).toList(),
        'deviceId': _getDeviceId(),
      },
    );

    _sendMessage(message);
    _log('Beacon verisi gönderildi: ${beacons.length} beacon');
  }

  /// Navigasyon isteği gönder
  void requestNavigation(String destinationId) {
    if (_connectionState != WebSocketConnectionState.connected) {
      _log('Bağlantı yok, navigasyon isteği gönderilemedi', isError: true);
      return;
    }

    final message = WebSocketMessage(
      type: WebSocketMessageType.requestNavigation,
      data: {
        'destinationId': destinationId,
        'deviceId': _getDeviceId(),
      },
    );

    _sendMessage(message);
    _log('Navigasyon isteği gönderildi: $destinationId');
  }

  /// Navigasyonu iptal et
  void cancelNavigation() {
    if (_connectionState != WebSocketConnectionState.connected) {
      return;
    }

    final message = WebSocketMessage(
      type: WebSocketMessageType.cancelNavigation,
      data: {'deviceId': _getDeviceId()},
    );

    _sendMessage(message);
    _navigationController.add(null);
    _log('Navigasyon iptal edildi');
  }

  /// Mesaj gönder
  void _sendMessage(WebSocketMessage message) {
    try {
      final jsonString = jsonEncode(message.toJson());
      _channel?.sink.add(jsonString);
    } catch (e) {
      _log('Mesaj gönderme hatası: $e', isError: true);
    }
  }

  /// Heartbeat başlat
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_connectionState == WebSocketConnectionState.connected) {
        _sendMessage(WebSocketMessage(type: WebSocketMessageType.ping));

        // Pong kontrolü
        if (_lastPongReceived != null) {
          final diff = DateTime.now().difference(_lastPongReceived!);
          if (diff.inSeconds > 60) {
            _log('Heartbeat timeout, yeniden bağlanılıyor...', isError: true);
            _scheduleReconnect();
          }
        }
      }
    });
  }

  /// Yeniden bağlanma planla
  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      _log('Maksimum yeniden bağlanma denemesi aşıldı', isError: true);
      _updateConnectionState(WebSocketConnectionState.error);
      return;
    }

    _reconnectTimer?.cancel();
    _updateConnectionState(WebSocketConnectionState.reconnecting);

    // Exponential backoff
    final delay = Duration(
      milliseconds: EnvConfig.websocketReconnectInterval * (_reconnectAttempts + 1),
    );

    _log('${delay.inSeconds} saniye sonra yeniden bağlanılacak (deneme: ${_reconnectAttempts + 1})');

    _reconnectTimer = Timer(delay, () {
      _reconnectAttempts++;
      connect();
    });
  }

  /// Bağlantı durumunu güncelle
  void _updateConnectionState(WebSocketConnectionState state) {
    _connectionState = state;
    _connectionStateController.add(state);
  }

  /// Cihaz ID'sini al (basit implementasyon)
  String _getDeviceId() {
    // Gerçek uygulamada device_info_plus paketi ile alınabilir
    return 'flutter_device_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Log yazdır
  void _log(String message, {bool isError = false}) {
    if (_isDebug) {
      final prefix = isError ? '❌ [WS ERROR]' : '🔌 [WS]';
      debugPrint('$prefix $message');
    }
  }

  /// Kaynakları temizle
  void dispose() {
    disconnect();
    _connectionStateController.close();
    _messageController.close();
    _locationController.close();
    _navigationController.close();
  }
}
