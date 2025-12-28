/// Beacon (BLE cihazı) model sınıfı
/// ESP32-C3 cihazlarından alınan sinyal bilgilerini temsil eder
class BeaconModel {
  /// Beacon'ın benzersiz MAC adresi
  final String macAddress;

  /// Beacon'ın adı (ESP32 tarafından yayınlanan)
  final String? name;

  /// Sinyal gücü (RSSI - Received Signal Strength Indicator)
  /// Değer ne kadar 0'a yakınsa sinyal o kadar güçlüdür
  /// Örnek: -30 dBm (çok yakın), -70 dBm (orta mesafe), -90 dBm (uzak)
  final int rssi;

  /// Son görülme zamanı
  final DateTime lastSeen;

  /// Beacon'ın harita üzerindeki konumu (backend'den gelir)
  final Position? position;

  /// Beacon'ın bulunduğu oda ID'si
  final String? roomId;

  BeaconModel({
    required this.macAddress,
    this.name,
    required this.rssi,
    DateTime? lastSeen,
    this.position,
    this.roomId,
  }) : lastSeen = lastSeen ?? DateTime.now();

  /// JSON'dan BeaconModel oluşturur
  factory BeaconModel.fromJson(Map<String, dynamic> json) {
    return BeaconModel(
      macAddress: json['macAddress'] as String,
      name: json['name'] as String?,
      rssi: json['rssi'] as int,
      lastSeen: json['lastSeen'] != null
          ? DateTime.parse(json['lastSeen'] as String)
          : DateTime.now(),
      position: json['position'] != null
          ? Position.fromJson(json['position'] as Map<String, dynamic>)
          : null,
      roomId: json['roomId'] as String?,
    );
  }

  /// BeaconModel'i JSON'a dönüştürür (backend'e gönderilecek format)
  Map<String, dynamic> toJson() {
    return {
      'macAddress': macAddress,
      'name': name,
      'rssi': rssi,
      'lastSeen': lastSeen.toIso8601String(),
      if (position != null) 'position': position!.toJson(),
      if (roomId != null) 'roomId': roomId,
    };
  }

  /// RSSI değerine göre tahmini mesafe (metre cinsinden)
  /// Not: Bu sadece yaklaşık bir değerdir, gerçek mesafe ortam koşullarına bağlıdır
  double get estimatedDistance {
    // Path loss modeli kullanarak mesafe tahmini
    // RSSI = TxPower - 10 * n * log10(d)
    // n = 2.0 (açık alan için), 2.5-4.0 (iç mekan için)
    const double txPower = -59; // 1 metre mesafedeki referans RSSI
    const double n = 2.5; // İç mekan için path loss üssü

    if (rssi == 0) return -1.0;

    final ratio = (txPower - rssi) / (10 * n);
    return double.parse(Math.pow(10, ratio).toStringAsFixed(2));
  }

  /// Sinyal kalitesi (0-100 arası)
  int get signalQuality {
    // RSSI: -30 (en iyi) ile -100 (en kötü) arasında
    if (rssi >= -50) return 100;
    if (rssi >= -60) return 80;
    if (rssi >= -70) return 60;
    if (rssi >= -80) return 40;
    if (rssi >= -90) return 20;
    return 0;
  }

  @override
  String toString() {
    return 'BeaconModel(mac: $macAddress, rssi: $rssi, quality: $signalQuality%)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BeaconModel && other.macAddress == macAddress;
  }

  @override
  int get hashCode => macAddress.hashCode;

  /// Güncellenmiş RSSI ile yeni kopya oluşturur
  BeaconModel copyWith({
    String? macAddress,
    String? name,
    int? rssi,
    DateTime? lastSeen,
    Position? position,
    String? roomId,
  }) {
    return BeaconModel(
      macAddress: macAddress ?? this.macAddress,
      name: name ?? this.name,
      rssi: rssi ?? this.rssi,
      lastSeen: lastSeen ?? this.lastSeen,
      position: position ?? this.position,
      roomId: roomId ?? this.roomId,
    );
  }
}

/// Konum model sınıfı
/// Harita üzerindeki x, y koordinatlarını temsil eder
class Position {
  /// X koordinatı (harita üzerinde)
  final double x;

  /// Y koordinatı (harita üzerinde)
  final double y;

  /// Kat numarası (çoklu kat desteği için)
  final int floor;

  const Position({
    required this.x,
    required this.y,
    this.floor = 0,
  });

  factory Position.fromJson(Map<String, dynamic> json) {
    return Position(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      floor: json['floor'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'x': x,
      'y': y,
      'floor': floor,
    };
  }

  /// İki konum arasındaki mesafeyi hesaplar
  double distanceTo(Position other) {
    final dx = x - other.x;
    final dy = y - other.y;
    return Math.sqrt(dx * dx + dy * dy);
  }

  @override
  String toString() => 'Position(x: $x, y: $y, floor: $floor)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Position &&
        other.x == x &&
        other.y == y &&
        other.floor == floor;
  }

  @override
  int get hashCode => Object.hash(x, y, floor);

  Position copyWith({double? x, double? y, int? floor}) {
    return Position(
      x: x ?? this.x,
      y: y ?? this.y,
      floor: floor ?? this.floor,
    );
  }
}

/// Basit matematik işlemleri için yardımcı sınıf
class Math {
  Math._();

  static double sqrt(double x) => x >= 0 ? _sqrt(x) : 0;

  static double _sqrt(double x) {
    if (x == 0) return 0;
    double guess = x / 2;
    for (int i = 0; i < 20; i++) {
      guess = (guess + x / guess) / 2;
    }
    return guess;
  }

  static double pow(double base, double exponent) {
    if (exponent == 0) return 1;
    if (base == 0) return 0;

    // Basit üs hesaplaması
    double result = 1;
    bool negative = exponent < 0;
    double exp = negative ? -exponent : exponent;

    // Tam sayı kısmı
    int intPart = exp.floor();
    for (int i = 0; i < intPart; i++) {
      result *= base;
    }

    // Ondalık kısım için yaklaşık hesaplama
    double fracPart = exp - intPart;
    if (fracPart > 0) {
      // Taylor serisi yaklaşımı
      double ln = _ln(base);
      result *= _exp(fracPart * ln);
    }

    return negative ? 1 / result : result;
  }

  static double _ln(double x) {
    if (x <= 0) return 0;
    double result = 0;
    double term = (x - 1) / (x + 1);
    double termSquared = term * term;
    double currentTerm = term;
    for (int i = 1; i < 100; i += 2) {
      result += currentTerm / i;
      currentTerm *= termSquared;
    }
    return 2 * result;
  }

  static double _exp(double x) {
    double result = 1;
    double term = 1;
    for (int i = 1; i < 50; i++) {
      term *= x / i;
      result += term;
    }
    return result;
  }
}
