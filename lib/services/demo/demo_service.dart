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

  /// Demo hedefler
  final List<Destination> destinations = [
    const Destination(
      id: '1',
      name: 'Sınıf 101',
      description: 'Matematik dersi',
      position: Position(x: 150, y: 200),
      category: DestinationCategory.classroom,
    ),
    const Destination(
      id: '2',
      name: 'Sınıf 102',
      description: 'Fizik dersi',
      position: Position(x: 300, y: 200),
      category: DestinationCategory.classroom,
    ),
    const Destination(
      id: '3',
      name: 'Müdür Odası',
      description: 'Yönetim',
      position: Position(x: 450, y: 150),
      category: DestinationCategory.office,
    ),
    const Destination(
      id: '4',
      name: 'Erkek Tuvalet',
      position: Position(x: 500, y: 300),
      category: DestinationCategory.restroom,
    ),
    const Destination(
      id: '5',
      name: 'Kız Tuvalet',
      position: Position(x: 500, y: 350),
      category: DestinationCategory.restroom,
    ),
    const Destination(
      id: '6',
      name: 'Kantin',
      description: 'Yeme içme alanı',
      position: Position(x: 200, y: 400),
      category: DestinationCategory.cafeteria,
    ),
    const Destination(
      id: '7',
      name: 'Kütüphane',
      description: 'Çalışma alanı',
      position: Position(x: 600, y: 200),
      category: DestinationCategory.library,
    ),
    const Destination(
      id: '8',
      name: 'Bilgisayar Lab',
      description: 'Bilgisayar laboratuvarı',
      position: Position(x: 350, y: 350),
      category: DestinationCategory.laboratory,
    ),
    const Destination(
      id: '9',
      name: 'Ana Çıkış',
      position: Position(x: 100, y: 500),
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
