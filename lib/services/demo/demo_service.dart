import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../core/config/env_config.dart';
import '../../models/models.dart';

/// Demo/Test Servisi
/// WebSocket ve BLE olmadan uygulamayı test etmek için simüle edilmiş veriler sağlar
class DemoService extends ChangeNotifier {
  /// Mevcut kullanıcı konumu
  UserLocation? _currentLocation;
  UserLocation? get currentLocation => _currentLocation;

  /// Aktif navigasyon rotası
  NavigationRoute? _activeRoute;
  NavigationRoute? get activeRoute => _activeRoute;

  /// Simülasyon timer'ı
  Timer? _simulationTimer;

  /// Random generator
  final _random = Random();

  /// Demo hedefler - SVG'deki gerçek oda isimleri
  final List<Destination> destinations = [
    // Ofisler
    const Destination(
      id: '161',
      name: 'TTO Ofisi',
      description: 'Teknoloji Transfer Ofisi',
      position: Position(x: 250, y: 100),
      category: DestinationCategory.office,
    ),
    const Destination(
      id: '141',
      name: 'Areli İletişim USAM',
      description: 'İletişim Merkezi',
      position: Position(x: 360, y: 345),
      category: DestinationCategory.office,
    ),
    const Destination(
      id: '145',
      name: 'Müh. Öğr. Çal. Ofisi',
      description: 'Mühendislik Öğrenci Çalışma Ofisi',
      position: Position(x: 870, y: 345),
      category: DestinationCategory.office,
    ),
    const Destination(
      id: '148',
      name: 'Araştırma Görevlisi Odası',
      description: 'Araştırma Görevlisi Girişi',
      position: Position(x: 1310, y: 345),
      category: DestinationCategory.office,
    ),
    // Derslikler
    const Destination(
      id: '160',
      name: 'Derslik 160',
      description: 'Üst kat derslik',
      position: Position(x: 370, y: 100),
      category: DestinationCategory.classroom,
    ),
    const Destination(
      id: '159',
      name: 'Derslik 159',
      position: Position(x: 500, y: 100),
      category: DestinationCategory.classroom,
    ),
    const Destination(
      id: '158',
      name: 'Derslik 158',
      position: Position(x: 630, y: 100),
      category: DestinationCategory.classroom,
    ),
    const Destination(
      id: '157',
      name: 'Derslik 157',
      position: Position(x: 760, y: 100),
      category: DestinationCategory.classroom,
    ),
    const Destination(
      id: '142',
      name: 'Derslik 142',
      position: Position(x: 490, y: 345),
      category: DestinationCategory.classroom,
    ),
    const Destination(
      id: '143',
      name: 'Derslik 143',
      position: Position(x: 620, y: 345),
      category: DestinationCategory.classroom,
    ),
    const Destination(
      id: '144',
      name: 'Derslik 144',
      position: Position(x: 750, y: 345),
      category: DestinationCategory.classroom,
    ),
    const Destination(
      id: '139',
      name: 'Derslik 139',
      position: Position(x: 105, y: 540),
      category: DestinationCategory.classroom,
    ),
    const Destination(
      id: '120',
      name: 'Derslik 120',
      position: Position(x: 360, y: 500),
      category: DestinationCategory.classroom,
    ),
    // Laboratuvarlar
    const Destination(
      id: '156',
      name: 'Kimya Laboratuvarı',
      description: 'Kimya Lab 156',
      position: Position(x: 1000, y: 100),
      category: DestinationCategory.laboratory,
    ),
    const Destination(
      id: '155',
      name: 'Modelleme Opt. Lab',
      description: 'Modelleme ve Optimizasyon Laboratuvarı',
      position: Position(x: 1160, y: 100),
      category: DestinationCategory.laboratory,
    ),
    const Destination(
      id: '151',
      name: 'Maket Atölyesi',
      description: 'Maket Atölyesi 151',
      position: Position(x: 1385, y: 100),
      category: DestinationCategory.laboratory,
    ),
    const Destination(
      id: '131',
      name: 'Temel Elektronik Lab',
      description: 'Temel Elektronik Laboratuvarı',
      position: Position(x: 1540, y: 100),
      category: DestinationCategory.laboratory,
    ),
    const Destination(
      id: '146',
      name: 'Fizik Laboratuvarı',
      description: 'Fizik Lab 146',
      position: Position(x: 1010, y: 345),
      category: DestinationCategory.laboratory,
    ),
    const Destination(
      id: '147',
      name: 'Büyük Veri ve IoT Lab',
      description: 'Büyük Veri ve Nesnelerin İnterneti Laboratuvarı',
      position: Position(x: 1175, y: 345),
      category: DestinationCategory.laboratory,
    ),
    const Destination(
      id: '149',
      name: 'Öğrenci Proje Ofisi',
      description: 'Öğrenci Projeleri Laboratuvarı',
      position: Position(x: 1430, y: 345),
      category: DestinationCategory.laboratory,
    ),
    const Destination(
      id: '150',
      name: 'Kalibrasyon Lab',
      description: 'Kalibrasyon ve Uygulamaları Laboratuvarı',
      position: Position(x: 1575, y: 345),
      category: DestinationCategory.laboratory,
    ),
    // WC ve Yemekhane
    const Destination(
      id: 'wc-1',
      name: 'WC (Üst Kat)',
      position: Position(x: 1275, y: 100),
      category: DestinationCategory.restroom,
    ),
    const Destination(
      id: 'wc-bay',
      name: 'WC Bay',
      position: Position(x: 105, y: 330),
      category: DestinationCategory.restroom,
    ),
    const Destination(
      id: 'yemekhane',
      name: 'Yemekhane',
      description: 'Yeme içme alanı',
      position: Position(x: 105, y: 230),
      category: DestinationCategory.cafeteria,
    ),
    // Giriş ve Merdivenler
    const Destination(
      id: 'entrance',
      name: 'Ana Giriş',
      description: 'Bina girişi',
      position: Position(x: 245, y: 695),
      category: DestinationCategory.exit,
    ),
  ];

  /// Servisi başlat
  void initialize() {
    _log('Demo servis başlatılıyor...');

    // Başlangıç konumu simüle et
    _currentLocation = UserLocation(
      position: const Position(x: 200, y: 300),
      accuracy: 1.5,
      timestamp: DateTime.now(),
      currentRoom: 'Koridor',
      usedBeaconCount: 3,
      confidence: 0.85,
    );

    // Konum simülasyonu başlat (notifyListeners build sonrası çağrılsın)
    Future.delayed(const Duration(milliseconds: 100), () {
      _startLocationSimulation();
      notifyListeners();
    });

    _log('Demo servis hazır');
  }

  /// Konum simülasyonu
  void _startLocationSimulation() {
    _simulationTimer?.cancel();
    _simulationTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _updateSimulatedLocation();
    });
  }

  /// Simüle edilmiş konumu güncelle
  void _updateSimulatedLocation() {
    if (_currentLocation == null) return;

    final current = _currentLocation!.position;

    // Navigasyon aktifse hedefe doğru hareket et
    if (_activeRoute != null && _activeRoute!.waypoints.isNotEmpty) {
      _moveTowardsDestination();
    } else {
      // Rastgele küçük hareket
      final newX = current.x + (_random.nextDouble() - 0.5) * 10;
      final newY = current.y + (_random.nextDouble() - 0.5) * 10;

      _currentLocation = _currentLocation!.copyWith(
        position: Position(
          x: newX.clamp(50, 750),
          y: newY.clamp(50, 550),
        ),
        timestamp: DateTime.now(),
        accuracy: 1.0 + _random.nextDouble() * 2,
        confidence: 0.7 + _random.nextDouble() * 0.3,
      );
    }

    notifyListeners();
  }

  /// Hedefe doğru hareket et (simülasyon)
  void _moveTowardsDestination() {
    if (_activeRoute == null || _activeRoute!.waypoints.isEmpty) return;

    final current = _currentLocation!.position;
    final destination = _activeRoute!.destination;

    // Hedefe olan mesafe
    final distance = current.distanceTo(destination);

    if (distance < 15) {
      // Hedefe ulaşıldı
      _log('🎯 Hedefe ulaşıldı: ${_activeRoute!.destinationName}');
      _currentLocation = _currentLocation!.copyWith(
        position: destination,
        currentRoom: _activeRoute!.destinationName,
        accuracy: 0.5,
        confidence: 0.95,
      );
      _activeRoute = null;
    } else {
      // Hedefe doğru hareket et
      final dx = destination.x - current.x;
      final dy = destination.y - current.y;
      final step = 15.0; // Her adımda 15 piksel

      final newX = current.x + (dx / distance) * step;
      final newY = current.y + (dy / distance) * step;

      _currentLocation = _currentLocation!.copyWith(
        position: Position(x: newX, y: newY),
        timestamp: DateTime.now(),
        accuracy: 1.5,
        confidence: 0.8,
      );
    }
  }

  /// Navigasyonu başlat
  void startNavigation(String destinationId) {
    final destination = destinations.firstWhere(
      (d) => d.id == destinationId,
      orElse: () => destinations.first,
    );

    _log('Navigasyon başlatılıyor: ${destination.name}');

    // Basit bir rota oluştur (düz çizgi)
    final start = _currentLocation?.position ?? const Position(x: 200, y: 300);
    final waypoints = _generateWaypoints(start, destination.position);

    _activeRoute = NavigationRoute(
      waypoints: waypoints,
      totalDistance: start.distanceTo(destination.position),
      estimatedTime: (start.distanceTo(destination.position) / 10).round(), // ~10 px/saniye
      start: start,
      destination: destination.position,
      destinationName: destination.name,
      status: RouteStatus.active,
    );

    notifyListeners();
  }

  /// Waypoint'ler oluştur (basit interpolasyon)
  List<Position> _generateWaypoints(Position start, Position end) {
    final waypoints = <Position>[start];

    // Ara noktalar ekle
    const steps = 5;
    for (int i = 1; i < steps; i++) {
      final t = i / steps;
      waypoints.add(Position(
        x: start.x + (end.x - start.x) * t,
        y: start.y + (end.y - start.y) * t,
      ));
    }

    waypoints.add(end);
    return waypoints;
  }

  /// Navigasyonu iptal et
  void cancelNavigation() {
    _log('Navigasyon iptal edildi');
    _activeRoute = null;
    notifyListeners();
  }

  /// Debug log
  void _log(String message) {
    if (EnvConfig.debugMode) {
      debugPrint('🎮 [Demo] $message');
    }
  }

  @override
  void dispose() {
    _simulationTimer?.cancel();
    super.dispose();
  }
}
