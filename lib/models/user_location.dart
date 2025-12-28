import 'beacon_model.dart';

/// Kullanıcının anlık konum bilgisini temsil eder
/// Backend'den gelen konum hesaplaması sonucunu içerir
class UserLocation {
  /// Hesaplanan konum
  final Position position;

  /// Konum doğruluk seviyesi (metre cinsinden)
  /// Değer ne kadar düşükse konum o kadar doğrudur
  final double accuracy;

  /// Konumun hesaplandığı zaman
  final DateTime timestamp;

  /// Kullanıcının bulunduğu oda (varsa)
  final String? currentRoom;

  /// Konumun hesaplanmasında kullanılan beacon sayısı
  final int usedBeaconCount;

  /// Güven seviyesi (0.0 - 1.0 arası)
  final double confidence;

  const UserLocation({
    required this.position,
    required this.accuracy,
    required this.timestamp,
    this.currentRoom,
    this.usedBeaconCount = 0,
    this.confidence = 0.0,
  });

  factory UserLocation.fromJson(Map<String, dynamic> json) {
    return UserLocation(
      position: Position.fromJson(json['position'] as Map<String, dynamic>),
      accuracy: (json['accuracy'] as num).toDouble(),
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
      currentRoom: json['currentRoom'] as String?,
      usedBeaconCount: json['usedBeaconCount'] as int? ?? 0,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'position': position.toJson(),
      'accuracy': accuracy,
      'timestamp': timestamp.toIso8601String(),
      if (currentRoom != null) 'currentRoom': currentRoom,
      'usedBeaconCount': usedBeaconCount,
      'confidence': confidence,
    };
  }

  /// Konum kalitesi durumu
  LocationQuality get quality {
    if (accuracy <= 1.0 && confidence >= 0.8) return LocationQuality.excellent;
    if (accuracy <= 2.0 && confidence >= 0.6) return LocationQuality.good;
    if (accuracy <= 4.0 && confidence >= 0.4) return LocationQuality.fair;
    return LocationQuality.poor;
  }

  @override
  String toString() {
    return 'UserLocation(position: $position, accuracy: ${accuracy.toStringAsFixed(2)}m, room: $currentRoom)';
  }

  UserLocation copyWith({
    Position? position,
    double? accuracy,
    DateTime? timestamp,
    String? currentRoom,
    int? usedBeaconCount,
    double? confidence,
  }) {
    return UserLocation(
      position: position ?? this.position,
      accuracy: accuracy ?? this.accuracy,
      timestamp: timestamp ?? this.timestamp,
      currentRoom: currentRoom ?? this.currentRoom,
      usedBeaconCount: usedBeaconCount ?? this.usedBeaconCount,
      confidence: confidence ?? this.confidence,
    );
  }
}

/// Konum kalitesi enumı
enum LocationQuality {
  excellent, // Mükemmel: <1m hata
  good, // İyi: 1-2m hata
  fair, // Orta: 2-4m hata
  poor, // Zayıf: >4m hata
}

/// LocationQuality için extension
extension LocationQualityExtension on LocationQuality {
  String get displayName {
    switch (this) {
      case LocationQuality.excellent:
        return 'Mükemmel';
      case LocationQuality.good:
        return 'İyi';
      case LocationQuality.fair:
        return 'Orta';
      case LocationQuality.poor:
        return 'Zayıf';
    }
  }

  String get icon {
    switch (this) {
      case LocationQuality.excellent:
        return '📍';
      case LocationQuality.good:
        return '📌';
      case LocationQuality.fair:
        return '📎';
      case LocationQuality.poor:
        return '❓';
    }
  }
}
