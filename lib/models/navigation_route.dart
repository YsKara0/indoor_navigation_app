import 'beacon_model.dart';

/// Navigasyon rotası modeli
/// Backend'den gelen rota bilgilerini temsil eder
class NavigationRoute {
  /// Rota üzerindeki nokta listesi
  final List<Position> waypoints;

  /// Toplam mesafe (metre)
  final double totalDistance;

  /// Tahmini varış süresi (saniye)
  final int estimatedTime;

  /// Başlangıç noktası
  final Position start;

  /// Bitiş noktası (hedef)
  final Position destination;

  /// Hedef oda/konum adı
  final String destinationName;

  /// Rotanın durumu
  final RouteStatus status;

  const NavigationRoute({
    required this.waypoints,
    required this.totalDistance,
    required this.estimatedTime,
    required this.start,
    required this.destination,
    required this.destinationName,
    this.status = RouteStatus.active,
  });

  factory NavigationRoute.fromJson(Map<String, dynamic> json) {
    return NavigationRoute(
      waypoints: (json['waypoints'] as List)
          .map((w) => Position.fromJson(w as Map<String, dynamic>))
          .toList(),
      totalDistance: (json['totalDistance'] as num).toDouble(),
      estimatedTime: json['estimatedTime'] as int,
      start: Position.fromJson(json['start'] as Map<String, dynamic>),
      destination: Position.fromJson(json['destination'] as Map<String, dynamic>),
      destinationName: json['destinationName'] as String,
      status: RouteStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => RouteStatus.active,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'waypoints': waypoints.map((w) => w.toJson()).toList(),
      'totalDistance': totalDistance,
      'estimatedTime': estimatedTime,
      'start': start.toJson(),
      'destination': destination.toJson(),
      'destinationName': destinationName,
      'status': status.name,
    };
  }

  /// Tahmini varış süresini okunabilir formatta döndürür
  String get formattedTime {
    if (estimatedTime < 60) {
      return '$estimatedTime saniye';
    } else {
      final minutes = estimatedTime ~/ 60;
      final seconds = estimatedTime % 60;
      return seconds > 0 ? '$minutes dk $seconds sn' : '$minutes dakika';
    }
  }

  /// Mesafeyi okunabilir formatta döndürür
  String get formattedDistance {
    if (totalDistance < 1000) {
      return '${totalDistance.toStringAsFixed(0)} m';
    } else {
      return '${(totalDistance / 1000).toStringAsFixed(1)} km';
    }
  }

  @override
  String toString() {
    return 'NavigationRoute(to: $destinationName, distance: $formattedDistance, time: $formattedTime)';
  }
}

/// Rota durumu
enum RouteStatus {
  /// Aktif navigasyon
  active,

  /// Hedefe ulaşıldı
  arrived,

  /// Rota iptal edildi
  cancelled,

  /// Rota yeniden hesaplanıyor
  recalculating,
}

/// Hedef konum modeli (aranabilir yerler)
class Destination {
  /// Benzersiz ID
  final String id;

  /// Konum adı
  final String name;

  /// Açıklama
  final String? description;

  /// Konum
  final Position position;

  /// Kategori
  final DestinationCategory category;

  /// İkon
  final String? icon;

  /// Kat numarası
  final int floor;

  const Destination({
    required this.id,
    required this.name,
    this.description,
    required this.position,
    required this.category,
    this.icon,
    this.floor = 0,
  });

  factory Destination.fromJson(Map<String, dynamic> json) {
    return Destination(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      position: Position.fromJson(json['position'] as Map<String, dynamic>),
      category: DestinationCategory.values.firstWhere(
        (c) => c.name == json['category'],
        orElse: () => DestinationCategory.other,
      ),
      icon: json['icon'] as String?,
      floor: json['floor'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (description != null) 'description': description,
      'position': position.toJson(),
      'category': category.name,
      if (icon != null) 'icon': icon,
      'floor': floor,
    };
  }
}

/// Hedef kategorileri
enum DestinationCategory {
  classroom, // Derslik
  office, // Ofis
  restroom, // Tuvalet
  cafeteria, // Yemekhane/Kantin
  library, // Kütüphane
  laboratory, // Laboratuvar
  exit, // Çıkış
  elevator, // Asansör
  stairs, // Merdiven
  other, // Diğer
}

/// DestinationCategory için extension
extension DestinationCategoryExtension on DestinationCategory {
  String get displayName {
    switch (this) {
      case DestinationCategory.classroom:
        return 'Derslik';
      case DestinationCategory.office:
        return 'Ofis';
      case DestinationCategory.restroom:
        return 'Tuvalet';
      case DestinationCategory.cafeteria:
        return 'Yemekhane';
      case DestinationCategory.library:
        return 'Kütüphane';
      case DestinationCategory.laboratory:
        return 'Laboratuvar';
      case DestinationCategory.exit:
        return 'Çıkış';
      case DestinationCategory.elevator:
        return 'Asansör';
      case DestinationCategory.stairs:
        return 'Merdiven';
      case DestinationCategory.other:
        return 'Diğer';
    }
  }

  String get emoji {
    switch (this) {
      case DestinationCategory.classroom:
        return '📚';
      case DestinationCategory.office:
        return '🏢';
      case DestinationCategory.restroom:
        return '🚻';
      case DestinationCategory.cafeteria:
        return '🍽️';
      case DestinationCategory.library:
        return '📖';
      case DestinationCategory.laboratory:
        return '🔬';
      case DestinationCategory.exit:
        return '🚪';
      case DestinationCategory.elevator:
        return '🛗';
      case DestinationCategory.stairs:
        return '🪜';
      case DestinationCategory.other:
        return '📍';
    }
  }
}
