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
    with SingleTickerProviderStateMixin {
  /// Zoom ve pan için transform controller
  final TransformationController _transformController = TransformationController();

  /// User marker animasyonu için controller
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  /// Minimum ve maksimum zoom seviyeleri
  final double _minScale = 0.5;
  final double _maxScale = 4.0;

  @override
  void initState() {
    super.initState();

    // Pulse animasyonu
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.5).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _transformController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.mapBackground,
      child: InteractiveViewer(
        transformationController: _transformController,
        minScale: _minScale,
        maxScale: _maxScale,
        boundaryMargin: const EdgeInsets.all(100),
        child: GestureDetector(
          onTapUp: (details) {
            if (widget.onMapTap != null) {
              // Transform edilmiş koordinatları hesapla
              final matrix = _transformController.value;
              final inverseMatrix = Matrix4.inverted(matrix);
              final transformedPoint = MatrixUtils.transformPoint(
                inverseMatrix,
                details.localPosition,
              );
              widget.onMapTap!(transformedPoint);
            }
          },
          child: Stack(
            children: [
              // Harita SVG
              _buildMap(),

              // Navigasyon rotası
              if (widget.activeRoute != null) _buildNavigationPath(),

              // Beacon'lar
              if (widget.beacons != null && widget.beacons!.isNotEmpty)
                ..._buildBeaconMarkers(),

              // Hedef işaretçisi
              if (widget.activeRoute != null) _buildDestinationMarker(),

              // Kullanıcı konumu
              if (widget.userLocation != null) _buildUserMarker(),
            ],
          ),
        ),
      ),
    );
  }

  /// Harita SVG widget'ı
  Widget _buildMap() {
    return SvgPicture.asset(
      widget.mapAssetPath,
      width: widget.mapSize.width,
      height: widget.mapSize.height,
      fit: BoxFit.contain,
    );
  }

  /// Kullanıcı konum işaretçisi
  Widget _buildUserMarker() {
    final position = widget.userLocation!.position;

    return Positioned(
      left: position.x - 16,
      top: position.y - 16,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, _) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // Pulse efekti
              Container(
                width: 32 * _pulseAnimation.value,
                height: 32 * _pulseAnimation.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.userLocation.withOpacity(0.3),
                ),
              ),
              // Merkez nokta
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.userLocation,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.userLocation.withOpacity(0.4),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.navigation,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Navigasyon rotası çizimi
  Widget _buildNavigationPath() {
    final route = widget.activeRoute!;

    return CustomPaint(
      size: widget.mapSize,
      painter: NavigationPathPainter(
        waypoints: route.waypoints,
        pathColor: AppColors.mapPath,
        strokeWidth: 4.0,
      ),
    );
  }

  /// Hedef işaretçisi
  Widget _buildDestinationMarker() {
    final destination = widget.activeRoute!.destination;

    return Positioned(
      left: destination.x - 14,
      top: destination.y - 28,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.destination,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              widget.activeRoute!.destinationName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Icon(
            Icons.location_on,
            color: AppColors.destination,
            size: 28,
          ),
        ],
      ),
    );
  }

  /// Beacon işaretçileri
  List<Widget> _buildBeaconMarkers() {
    return widget.beacons!.map((beacon) {
      if (beacon.position == null) return const SizedBox.shrink();

      return Positioned(
        left: beacon.position!.x - 8,
        top: beacon.position!.y - 8,
        child: Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _getBeaconColor(beacon),
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: const Icon(
            Icons.bluetooth,
            size: 8,
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

  NavigationPathPainter({
    required this.waypoints,
    required this.pathColor,
    this.strokeWidth = 4.0,
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
    path.moveTo(waypoints.first.x, waypoints.first.y);

    for (int i = 1; i < waypoints.length; i++) {
      path.lineTo(waypoints[i].x, waypoints[i].y);
    }

    // Glow efekti
    canvas.drawPath(path, dashPaint);

    // Ana çizgi
    canvas.drawPath(path, paint);

    // Waypoint noktaları
    final dotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    for (final point in waypoints) {
      canvas.drawCircle(Offset(point.x, point.y), 4, dotPaint);
      canvas.drawCircle(Offset(point.x, point.y), 3, paint..style = PaintingStyle.fill);
    }
  }

  @override
  bool shouldRepaint(covariant NavigationPathPainter oldDelegate) {
    return waypoints != oldDelegate.waypoints;
  }
}
