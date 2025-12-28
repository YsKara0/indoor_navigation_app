import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/config/env_config.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import '../../widgets/widgets.dart';
import '../test/beacon_test_screen.dart';

/// Ana navigasyon ekranı
/// Harita, konum bilgisi ve navigasyon kontrollerini içerir
class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen>
    with WidgetsBindingObserver {
  /// Demo modu mu? (runtime'da değiştirilebilir)
  bool _isDemoMode = false;

  /// Başlatıldı mı?
  bool _isInitialized = false;

  /// Mode badge tap sayısı (3 kez tıklayınca mod değişir)
  int _modeTapCount = 0;
  DateTime? _lastModeTap;
  
  /// Long press için timer
  Timer? _longPressTimer;
  bool _isLongPressing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Servisleri build sonrası başlat
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeServices();
    });
  }

  @override
  void dispose() {
    _longPressTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isDemoMode) return;
    
    final bleService = context.read<BleService>();
    if (state == AppLifecycleState.paused) {
      bleService.stopScanning();
    } else if (state == AppLifecycleState.resumed) {
      bleService.startScanning();
    }
  }

  /// Servisleri başlat
  Future<void> _initializeServices() async {
    if (_isDemoMode) {
      // Demo modunda sadece demo servisi başlat
      debugPrint('🎮 Demo modu aktif');
      context.read<DemoService>().initialize();
      setState(() => _isInitialized = true);
    } else {
      // Gerçek modda BLE ve WebSocket servislerini başlat
      final bleService = context.read<BleService>();
      final wsService = context.read<WebSocketService>();

      bleService.onBeaconsUpdated = (beacons) {
        wsService.sendBeaconData(beacons);
      };

      await wsService.initialize();
      final bleReady = await bleService.initialize();

      if (bleReady) {
        await bleService.startScanning();
      }

      setState(() => _isInitialized = true);
    }
  }

  /// Bağlantıları yeniden dene
  Future<void> _retryConnections() async {
    if (_isDemoMode) return;
    
    await context.read<WebSocketService>().connect();
    await context.read<BleService>().startScanning();
  }

  /// Hedef arama sheet'ini göster
  void _showDestinationSearch() {
    final destinations = _isDemoMode
        ? context.read<DemoService>().destinations
        : context.read<DemoService>().destinations; // TODO: Backend'den al

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => DestinationSearchSheet(
          destinations: destinations,
          onDestinationSelected: _startNavigationTo,
        ),
      ),
    );
  }

  /// Navigasyonu başlat
  void _startNavigationTo(Destination destination) {
    if (_isDemoMode) {
      context.read<DemoService>().startNavigation(destination.id);
    } else {
      context.read<WebSocketService>().startNavigation(destination.id);
    }

    TopNotification.navigation(context, destination.name);
  }

  /// Navigasyonu iptal et
  void _cancelNavigation() {
    if (_isDemoMode) {
      context.read<DemoService>().cancelNavigation();
    } else {
      context.read<WebSocketService>().cancelNavigation();
    }

    TopNotification.warning(context, 'Navigasyon iptal edildi', icon: Icons.cancel);
  }

  /// Demo badge'ine tıklama - 3 kez mod değişir
  void _onModeBadgeTap() {
    final now = DateTime.now();
    
    // 2 saniye içinde tıklanmadıysa sayacı sıfırla
    if (_lastModeTap != null && now.difference(_lastModeTap!).inSeconds > 2) {
      _modeTapCount = 0;
    }
    
    _lastModeTap = now;
    _modeTapCount++;
    
    if (_modeTapCount >= 3) {
      // 3 kez tıklama - Mod değiştir
      _modeTapCount = 0;
      _toggleMode();
    }
  }

  /// 10 saniye basılı tutunca test sayfası açılır
  void _onModeBadgeLongPressStart() {
    _isLongPressing = true;
    _longPressTimer = Timer(const Duration(seconds: 10), () {
      if (_isLongPressing) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const BeaconTestScreen(),
          ),
        );
      }
    });
    
    // Kullanıcıya bilgi ver
    TopNotification.info(context, 'Test sayfası için 10 saniye basılı tutun...', icon: Icons.touch_app);
  }

  /// Basılı tutma bırakıldığında
  void _onModeBadgeLongPressEnd() {
    _isLongPressing = false;
    _longPressTimer?.cancel();
  }

  /// Demo/Production mod geçişi
  void _toggleMode() {
    setState(() {
      _isDemoMode = !_isDemoMode;
      _isInitialized = false;
    });
    
    // Servisleri yeniden başlat
    _initializeServices();
    
    if (_isDemoMode) {
      TopNotification.warning(context, 'Demo moduna geçildi', icon: Icons.science);
    } else {
      TopNotification.success(context, 'Normal moda geçildi', icon: Icons.cell_tower);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isDemoMode) {
      return _buildDemoMode();
    } else {
      return _buildProductionMode();
    }
  }

  /// Demo mod UI
  Widget _buildDemoMode() {
    return Scaffold(
      backgroundColor: AppColors.mapBackground,
      body: Consumer<DemoService>(
        builder: (context, demoService, child) {
          return Stack(
            children: [
              // Harita - tam ekran
              Positioned.fill(
                child: IndoorMapWidget(
                  mapAssetPath: 'assets/school_floor.svg',
                  userLocation: demoService.currentLocation,
                  activeRoute: demoService.activeRoute,
                  mapSize: const Size(800, 600),
                ),
              ),

              // Üst bar
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _buildDemoTopBar(),
              ),

              // Alt bilgi kartı - Draggable
              _buildDraggableBottomSheet(demoService),

              // Loading overlay
              if (!_isInitialized) _buildLoadingOverlay(),
            ],
          );
        },
      ),
    );
  }

  /// Draggable Bottom Sheet
  Widget _buildDraggableBottomSheet(DemoService demoService) {
    return DraggableScrollableSheet(
      initialChildSize: 0.28,
      minChildSize: 0.25,
      maxChildSize: 0.5,
      snap: true,
      snapSizes: const [0.25, 0.35, 0.5],
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom + 16,
                left: 16,
                right: 16,
                top: 8,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Tutma çubuğu (drag handle)
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.textHint.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  
                  // Konum bilgi kartı
                  LocationInfoCard(
                    location: demoService.currentLocation,
                    activeRoute: demoService.activeRoute,
                  ),

                  const SizedBox(height: 16),

                  // Navigasyon aktifse iptal butonu, değilse arama butonu
                  if (demoService.activeRoute != null)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _cancelNavigation,
                        icon: const Icon(Icons.close),
                        label: const Text('Navigasyonu İptal Et'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _showDestinationSearch,
                        icon: const Icon(Icons.search),
                        label: const Text('Nereye gitmek istiyorsunuz?'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Production mod UI
  Widget _buildProductionMode() {
    return Scaffold(
      backgroundColor: AppColors.mapBackground,
      body: Consumer2<BleService, WebSocketService>(
        builder: (context, bleService, wsService, child) {
          return Stack(
            children: [
              // Harita - tam ekran
              Positioned.fill(
                child: IndoorMapWidget(
                  mapAssetPath: 'assets/school_floor.svg',
                  userLocation: wsService.currentLocation,
                  activeRoute: wsService.activeRoute,
                  mapSize: const Size(800, 600),
                ),
              ),

              // Üst bar
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _buildTopBar(bleService, wsService),
              ),

              // Alt bilgi kartı - Draggable
              _buildProductionDraggableBottomSheet(wsService),

              if (!_isInitialized) _buildLoadingOverlay(),
            ],
          );
        },
      ),
    );
  }

  /// Production Draggable Bottom Sheet
  Widget _buildProductionDraggableBottomSheet(WebSocketService wsService) {
    return DraggableScrollableSheet(
      initialChildSize: 0.28,
      minChildSize: 0.25,
      maxChildSize: 0.5,
      snap: true,
      snapSizes: const [0.25, 0.35, 0.5],
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom + 16,
                left: 16,
                right: 16,
                top: 8,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Tutma çubuğu (drag handle)
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.textHint.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  
                  // Konum bilgi kartı
                  LocationInfoCard(
                    location: wsService.currentLocation,
                    activeRoute: wsService.activeRoute,
                  ),

                  const SizedBox(height: 16),

                  // Navigasyon aktifse iptal butonu, değilse arama butonu
                  if (wsService.activeRoute != null)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _cancelNavigation,
                        icon: const Icon(Icons.close),
                        label: const Text('Navigasyonu İptal Et'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _showDestinationSearch,
                        icon: const Icon(Icons.search),
                        label: const Text('Nereye gitmek istiyorsunuz?'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Demo üst bar
  Widget _buildDemoTopBar() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        bottom: 8,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withOpacity(0.95),
            Colors.white.withOpacity(0.0),
          ],
        ),
      ),
      child: Row(
        children: [
          const Text(
            'Indoor Navigation',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ).animate().fadeIn().slideX(begin: -0.2),
          const Spacer(),
          // Demo modu etiketi - 3 kez mod değişir, 10 saniye basılı tutunca test sayfası
          GestureDetector(
            onTap: _onModeBadgeTap,
            onLongPressStart: (_) => _onModeBadgeLongPressStart(),
            onLongPressEnd: (_) => _onModeBadgeLongPressEnd(),
            onLongPressCancel: _onModeBadgeLongPressEnd,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.warning),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.science, size: 14, color: AppColors.warning),
                  SizedBox(width: 4),
                  Text(
                    'DEMO',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.warning,
                    ),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn().scale(),
        ],
      ),
    );
  }

  /// Üst bar (production)
  Widget _buildTopBar(BleService bleService, WebSocketService wsService) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 4,
        left: 12,
        right: 12,
        bottom: 4,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withOpacity(0.95),
            Colors.white.withOpacity(0.0),
          ],
        ),
      ),
      child: Row(
        children: [
          const Text(
            'Indoor Nav',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          // Normal mod etiketi - 3 kez demo moduna geçer, 10 saniye basılı tutunca test sayfası
          GestureDetector(
            onTap: _onModeBadgeTap,
            onLongPressStart: (_) => _onModeBadgeLongPressStart(),
            onLongPressEnd: (_) => _onModeBadgeLongPressEnd(),
            onLongPressCancel: _onModeBadgeLongPressEnd,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.success),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cell_tower, size: 12, color: AppColors.success),
                  SizedBox(width: 2),
                  Text(
                    'LIVE',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          ConnectionStatusWidget(
            wsState: wsService.connectionState,
            bleState: bleService.scanState,
            onRetry: _retryConnections,
          ),
        ],
      ),
    );
  }

  /// Loading overlay
  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.white,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 24),
            Text(
              'Servisler başlatılıyor...',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
