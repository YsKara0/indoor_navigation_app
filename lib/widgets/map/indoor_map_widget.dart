import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';

/// Indoor Map Widget
/// Harita görüntüleme, kullanıcı konumu ve navigasyon rotası gösterimi
class IndoorMapWidget extends StatefulWidget {
  /// Harita SVG asset yolu
  final String mapAssetPath;

  /// Kullanıcının mevcut konumu
  final UserLocation? userLocation;

  /// Aktif navigasyon rotası
  final NavigationRoute? activeRoute;

  /// Harita üzerindeki beacon'lar
  final List<BeaconModel>? beacons;

  /// Harita üzerine tıklama callback'i
  final Function(Offset)? onMapTap;

  /// Harita boyutu (piksel cinsinden)
  final Size mapSize;

  const IndoorMapWidget({
    super.key,
    required this.mapAssetPath,
    this.userLocation,
    this.activeRoute,
    this.beacons,
    this.onMapTap,
    this.mapSize = const Size(800, 600),
  });

  @override
  State<IndoorMapWidget> createState() => _IndoorMapWidgetState();
}

class _IndoorMapWidgetState extends State<IndoorMapWidget>
    with TickerProviderStateMixin {
  /// Zoom ve pan için transform controller
  final TransformationController _transformController = TransformationController();

  /// User marker animasyonu için controller
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  /// Konum geçiş animasyonu
  late AnimationController _positionController;
  Position? _previousPosition;
  Position? _currentPosition;

  /// Minimum ve maksimum zoom seviyeleri
  final double _minScale = 0.5;
  final double _maxScale = 4.0;

  @override
  void initState() {
    super.initState();

    // Pulse animasyonu - sadece opacity için
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Konum geçiş animasyonu
    _positionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    
    // İlk konum
    if (widget.userLocation != null) {
      _currentPosition = widget.userLocation!.position;
      _previousPosition = _currentPosition;
    }
  }

  @override
  void didUpdateWidget(IndoorMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Konum değiştiyse animasyonlu geçiş yap
    if (widget.userLocation != null && 
        widget.userLocation!.position != _currentPosition) {
      _previousPosition = _currentPosition ?? widget.userLocation!.position;
      _currentPosition = widget.userLocation!.position;
      
      _positionController.reset();
      _positionController.forward();
    }
  }

  @override
  void dispose() {
    _transformController.dispose();
    _pulseController.dispose();
    _positionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Ekran boyutuna göre ölçek hesapla
          final scaleX = constraints.maxWidth / widget.mapSize.width;
          final scaleY = constraints.maxHeight / widget.mapSize.height;
          final scale = scaleX < scaleY ? scaleX : scaleY; // Küçük olanı seç (contain)

          final scaledWidth = widget.mapSize.width * scale;
          final scaledHeight = widget.mapSize.height * scale;

          return InteractiveViewer(
            transformationController: _transformController,
            minScale: _minScale,
            maxScale: _maxScale,
            boundaryMargin: const EdgeInsets.all(50),
            child: GestureDetector(
              onTapUp: (details) {
                if (widget.onMapTap != null) {
                  final matrix = _transformController.value;
                  final inverseMatrix = Matrix4.inverted(matrix);
                  final transformedPoint = MatrixUtils.transformPoint(
                    inverseMatrix,
                    details.localPosition,
                  );
                  // Ölçeği geri al
                  widget.onMapTap!(Offset(
                    transformedPoint.dx / scale,
                    transformedPoint.dy / scale,
                  ));
                }
              },
              child: Center(
                child: SizedBox(
                  width: scaledWidth,
                  height: scaledHeight,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Harita SVG
                      _buildMap(scaledWidth, scaledHeight),

                      // Navigasyon rotası
                      if (widget.activeRoute != null) 
                        _buildNavigationPath(scale),

                      // Beacon'lar
                      if (widget.beacons != null && widget.beacons!.isNotEmpty)
                        ..._buildBeaconMarkers(scale),

                      // Hedef işaretçisi
                      if (widget.activeRoute != null) 
                        _buildDestinationMarker(scale),

                      // Kullanıcı konumu
                      if (widget.userLocation != null) 
                        _buildUserMarker(scale),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Harita SVG widget'ı
  Widget _buildMap(double width, double height) {
    return SvgPicture.asset(
      widget.mapAssetPath,
      width: width,
      height: height,
      fit: BoxFit.fill,
      colorFilter: null,
      theme: const SvgTheme(
        currentColor: Colors.black,
      ),
      placeholderBuilder: (context) => Container(
        width: width,
        height: height,
        color: Colors.white,
        child: const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  /// Kullanıcı konum işaretçisi - Modern Google Maps tarzı
  Widget _buildUserMarker(double scale) {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseAnimation, _positionController]),
      builder: (context, _) {
        // Animasyonlu pozisyon hesapla
        final prevPos = _previousPosition ?? widget.userLocation!.position;
        final currPos = _currentPosition ?? widget.userLocation!.position;
        
        final animatedX = prevPos.x + (currPos.x - prevPos.x) * 
            Curves.easeInOutCubic.transform(_positionController.value);
        final animatedY = prevPos.y + (currPos.y - prevPos.y) * 
            Curves.easeInOutCubic.transform(_positionController.value);

        // Ölçeklenmiş koordinatlar
        final scaledX = animatedX * scale;
        final scaledY = animatedY * scale;
        
        // Sabit küçük marker boyutu
        const double dotSize = 10.0;
        const double pulseSize = 22.0;

        return Positioned(
          left: scaledX - pulseSize / 2,
          top: scaledY - pulseSize / 2,
          child: SizedBox(
            width: pulseSize,
            height: pulseSize,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Pulse efekti - sabit boyut, değişen opacity
                Container(
                  width: pulseSize,
                  height: pulseSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.userLocation.withOpacity(0.15 * _pulseAnimation.value),
                  ),
                ),
                // Mavi daire - kullanıcı konumu
                Container(
                  width: dotSize,
                  height: dotSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.userLocation,
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Navigasyon rotası çizimi
  Widget _buildNavigationPath(double scale) {
    final route = widget.activeRoute!;

    return CustomPaint(
      size: Size(widget.mapSize.width * scale, widget.mapSize.height * scale),
      painter: NavigationPathPainter(
        waypoints: route.waypoints,
        pathColor: AppColors.mapPath,
        strokeWidth: 4.0 * scale.clamp(0.5, 1.5),
        scale: scale,
      ),
    );
  }

  /// Hedef işaretçisi
  Widget _buildDestinationMarker(double scale) {
    final destination = widget.activeRoute!.destination;
    final scaledX = destination.x * scale;
    final scaledY = destination.y * scale;
    final iconSize = 28 * scale.clamp(0.5, 1.5);

    return Positioned(
      left: scaledX - iconSize / 2,
      top: scaledY - iconSize,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: 8 * scale.clamp(0.5, 1.5),
              vertical: 4 * scale.clamp(0.5, 1.5),
            ),
            decoration: BoxDecoration(
              color: AppColors.destination,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              widget.activeRoute!.destinationName,
              style: TextStyle(
                color: Colors.white,
                fontSize: 10 * scale.clamp(0.5, 1.5),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Icon(
            Icons.location_on,
            color: AppColors.destination,
            size: iconSize,
          ),
        ],
      ),
    );
  }

  /// Beacon işaretçileri
  List<Widget> _buildBeaconMarkers(double scale) {
    return widget.beacons!.map((beacon) {
      if (beacon.position == null) return const SizedBox.shrink();

      final scaledX = beacon.position!.x * scale;
      final scaledY = beacon.position!.y * scale;
      final markerSize = 16 * scale.clamp(0.5, 1.5);

      return Positioned(
        left: scaledX - markerSize / 2,
        top: scaledY - markerSize / 2,
        child: Container(
          width: markerSize,
          height: markerSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _getBeaconColor(beacon),
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Icon(
            Icons.bluetooth,
            size: markerSize / 2,
            color: Colors.white,
          ),
        ),
      );
    }).toList();
  }

  /// Beacon rengini sinyal gücüne göre belirle
  Color _getBeaconColor(BeaconModel beacon) {
    final quality = beacon.signalQuality;
    if (quality >= 60) return AppColors.beaconActive;
    if (quality >= 30) return AppColors.warning;
    return AppColors.beaconInactive;
  }
}

/// Navigasyon rotası çizici
class NavigationPathPainter extends CustomPainter {
  final List<Position> waypoints;
  final Color pathColor;
  final double strokeWidth;
  final double scale;

  NavigationPathPainter({
    required this.waypoints,
    required this.pathColor,
    this.strokeWidth = 4.0,
    this.scale = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (waypoints.length < 2) return;

    final paint = Paint()
      ..color = pathColor
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    // Dashed line efekti için
    final dashPaint = Paint()
      ..color = pathColor.withOpacity(0.5)
      ..strokeWidth = strokeWidth + 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(waypoints.first.x * scale, waypoints.first.y * scale);

    for (int i = 1; i < waypoints.length; i++) {
      path.lineTo(waypoints[i].x * scale, waypoints[i].y * scale);
    }

    // Glow efekti
    canvas.drawPath(path, dashPaint);

    // Ana çizgi
    canvas.drawPath(path, paint);

    // Waypoint noktaları
    final dotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final dotRadius = 4 * scale.clamp(0.5, 1.5);

    for (final point in waypoints) {
      final scaledPoint = Offset(point.x * scale, point.y * scale);
      canvas.drawCircle(scaledPoint, dotRadius, dotPaint);
      canvas.drawCircle(scaledPoint, dotRadius * 0.75, paint..style = PaintingStyle.fill);
    }
  }

  @override
  bool shouldRepaint(covariant NavigationPathPainter oldDelegate) {
    return waypoints != oldDelegate.waypoints || scale != oldDelegate.scale;
  }
}
