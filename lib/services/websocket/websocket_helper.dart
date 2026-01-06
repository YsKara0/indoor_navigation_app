import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
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
    DateTime? parsedTimestamp;
    final ts = json['timestamp'];
    if (ts != null) {
      if (ts is int) {
        parsedTimestamp = DateTime.fromMillisecondsSinceEpoch(ts);
      } else if (ts is String) {
        parsedTimestamp = DateTime.tryParse(ts);
      }
    }
    
    return WebSocketMessage(
      type: _parseMessageType(json['type'] as String?),
      data: json['data'] as Map<String, dynamic>?,
      error: json['error'] as String?,
      timestamp: parsedTimestamp ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    // Backend'in beklediği format
    String typeString;
    switch (type) {
      case WebSocketMessageType.beaconData:
        typeString = 'location'; // Backend 'location' bekliyor
        break;
      case WebSocketMessageType.requestNavigation:
        typeString = 'requestNavigation';
        break;
      case WebSocketMessageType.cancelNavigation:
        typeString = 'cancelNavigation';
        break;
      case WebSocketMessageType.ping:
        typeString = 'ping';
        break;
      default:
        typeString = type.name;
    }
    
    return {
      'type': typeString,
      if (data != null) 'data': data,
      if (error != null) 'error': error,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  static WebSocketMessageType _parseMessageType(String? type) {
    switch (type?.toUpperCase()) {
      case 'LOCATION':  // Backend'den gelen format
      case 'LOCATION_UPDATE':
        return WebSocketMessageType.locationUpdate;
      case 'BEACON_DATA':
        return WebSocketMessageType.beaconData;
      case 'NAVIGATION_PATH':
      case 'NAVIGATION':  // Backend alternatif format
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
      case 'WELCOME':  // Backend hoşgeldin mesajı
        return WebSocketMessageType.pong; // Ignore olarak işle
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

  /// Aktif navigasyon hedefi
  String? _activeTarget;

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
      _log('Hedef URL: $url');
      
      // Debug modda SSL sertifika doğrulamasını atla
      if (_isDebug || kDebugMode) {
        _log('Debug modu: SSL doğrulama gevşetildi');
        
        // SSL sertifika doğrulamasını devre dışı bırakan HttpClient
        final httpClient = HttpClient()
          ..badCertificateCallback = (X509Certificate cert, String host, int port) {
            _log('SSL Sertifika kabul edildi: host=$host, port=$port');
            return true; // Tüm sertifikaları kabul et (sadece debug için!)
          };
        
        final socket = await WebSocket.connect(
          url,
          customClient: httpClient,
        );
        _channel = IOWebSocketChannel(socket);
      } else {
        // Production'da normal bağlantı
        _channel = WebSocketChannel.connect(Uri.parse(url));
      }

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
          // RAW mesajı logla - debug için
          _log('RAW mesaj: $data');
          
          final jsonData = jsonDecode(data as String) as Map<String, dynamic>;
          
          // Backend'den gelen mesaj tipini kontrol et
          final messageType = jsonData['type'] as String?;
          
          // location mesajı ise direkt işle (backend root level'da veri gönderiyor)
          if (messageType?.toUpperCase() == 'LOCATION' && jsonData['status'] == 'ok') {
            _log('Konum verisi alındı: x=${jsonData['x']}, y=${jsonData['y']}, room=${jsonData['nearestRoom']}');
            
            // UserLocation oluştur
            final location = UserLocation(
              position: Position(
                x: (jsonData['x'] as num).toDouble(),
                y: (jsonData['y'] as num).toDouble(),
              ),
              accuracy: (jsonData['estimatedDistance'] as num?)?.toDouble() ?? 1.0,
              timestamp: DateTime.now(),
              currentRoom: jsonData['nearestRoom'] as String?,
              usedBeaconCount: 3,
              confidence: (jsonData['confidence'] as num?)?.toDouble() ?? 0.8,
            );
            
            _locationController.add(location);
            
            // Rota bilgisi varsa işle
            if (jsonData['hasRoute'] == true && jsonData['path'] != null) {
              _log('Rota bilgisi alındı: ${(jsonData['path'] as List).length} waypoint');
              
              final pathList = jsonData['path'] as List;
              final waypoints = pathList.map((p) => Position(
                x: (p['x'] as num).toDouble(),
                y: (p['y'] as num).toDouble(),
              )).toList();
              
              // NavigationRoute oluştur
              if (waypoints.isNotEmpty && _activeTarget != null) {
                final route = NavigationRoute(
                  start: waypoints.first,
                  destination: waypoints.last,
                  destinationName: _activeTarget!,
                  waypoints: waypoints,
                  totalDistance: _calculateTotalDistance(waypoints),
                  estimatedTime: (waypoints.length * 3), // Yaklaşık süre (saniye)
                );
                _navigationController.add(route);
              }
            }
            
            return; // İşlem tamamlandı
          }
          
          // Diğer mesajlar için normal parse
          final message = WebSocketMessage.fromJson(jsonData);
          _log('Mesaj alındı: ${message.type}');
          _messageController.add(message);

          // Mesaj tipine göre işle
          _handleMessage(message);
        } catch (e) {
          _log('Mesaj parse hatası: $e', isError: true);
          _log('Raw data: $data', isError: true);
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

    // Backend'in beklediği format: type=location, beacons array, opsiyonel target
    final messageData = {
      'type': 'location',
      'beacons': beacons.map((b) => {
        'macAddress': b.macAddress,
        'rssi': b.rssi,
        'name': b.name,
      }).toList(),
      'deviceId': _getDeviceId(),
      // Eğer aktif navigasyon varsa target ekle
      if (_activeTarget != null) 'target': _activeTarget,
    };

    _sendRawMessage(messageData);
    _log('Beacon verisi gönderildi: ${beacons.length} beacon${_activeTarget != null ? ", hedef: $_activeTarget" : ""}');
  }
  
  /// Raw JSON mesaj gönder
  void _sendRawMessage(Map<String, dynamic> data) {
    if (_channel != null && _connectionState == WebSocketConnectionState.connected) {
      final jsonString = jsonEncode(data);
      _log('Gönderilen mesaj: $jsonString');
      _channel!.sink.add(jsonString);
    }
  }

  /// Navigasyon isteği gönder - backend'de ayrı bir mesaj tipi yok
  /// Navigasyon, location mesajına 'target' parametresi ekleyerek yapılır
  void requestNavigation(String destinationId) {
    _activeTarget = destinationId;
    _log('Navigasyon hedefi ayarlandı: $destinationId');
    _log('Sonraki beacon gönderiminde rota hesaplanacak');
  }

  /// Navigasyonu iptal et
  void cancelNavigation() {
    _activeTarget = null;
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

  /// Toplam mesafeyi hesapla (piksel cinsinden)
  double _calculateTotalDistance(List<Position> waypoints) {
    if (waypoints.length < 2) return 0;
    
    double total = 0;
    for (int i = 0; i < waypoints.length - 1; i++) {
      final dx = waypoints[i + 1].x - waypoints[i].x;
      final dy = waypoints[i + 1].y - waypoints[i].y;
      total += sqrt(dx * dx + dy * dy);
    }
    return total / 18.0; // Piksel -> metre dönüşümü (backend'de 18px = 1m)
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
