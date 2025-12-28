import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Üst bildirim türleri
enum NotificationType {
  success,
  error,
  warning,
  info,
}

/// Üst bildirim widget'ı
class TopNotification {
  static OverlayEntry? _currentOverlay;
  static Timer? _dismissTimer;

  /// Bildirimi göster
  static void show(
    BuildContext context, {
    required String message,
    NotificationType type = NotificationType.info,
    Duration duration = const Duration(seconds: 3),
    IconData? icon,
  }) {
    // Önceki bildirimi kapat
    dismiss();

    final overlay = Overlay.of(context);

    _currentOverlay = OverlayEntry(
      builder: (context) => _TopNotificationWidget(
        message: message,
        type: type,
        icon: icon,
        onDismiss: dismiss,
      ),
    );

    overlay.insert(_currentOverlay!);

    // Otomatik kapatma
    _dismissTimer = Timer(duration, dismiss);
  }

  /// Başarı bildirimi
  static void success(BuildContext context, String message, {IconData? icon}) {
    show(context, message: message, type: NotificationType.success, icon: icon ?? Icons.check_circle);
  }

  /// Hata bildirimi
  static void error(BuildContext context, String message, {IconData? icon}) {
    show(context, message: message, type: NotificationType.error, icon: icon ?? Icons.error);
  }

  /// Uyarı bildirimi
  static void warning(BuildContext context, String message, {IconData? icon}) {
    show(context, message: message, type: NotificationType.warning, icon: icon ?? Icons.warning);
  }

  /// Bilgi bildirimi
  static void info(BuildContext context, String message, {IconData? icon}) {
    show(context, message: message, type: NotificationType.info, icon: icon ?? Icons.info);
  }

  /// Navigasyon bildirimi
  static void navigation(BuildContext context, String destination) {
    show(
      context,
      message: '$destination konumuna navigasyon başlatıldı',
      type: NotificationType.success,
      icon: Icons.navigation,
    );
  }

  /// Bildirimi kapat
  static void dismiss() {
    _dismissTimer?.cancel();
    _currentOverlay?.remove();
    _currentOverlay = null;
  }
}

class _TopNotificationWidget extends StatefulWidget {
  final String message;
  final NotificationType type;
  final IconData? icon;
  final VoidCallback onDismiss;

  const _TopNotificationWidget({
    required this.message,
    required this.type,
    this.icon,
    required this.onDismiss,
  });

  @override
  State<_TopNotificationWidget> createState() => _TopNotificationWidgetState();
}

class _TopNotificationWidgetState extends State<_TopNotificationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _slideAnimation = Tween<double>(begin: -1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    await _controller.reverse();
    widget.onDismiss();
  }

  Color get _backgroundColor {
    switch (widget.type) {
      case NotificationType.success:
        return AppColors.success;
      case NotificationType.error:
        return AppColors.error;
      case NotificationType.warning:
        return AppColors.warning;
      case NotificationType.info:
        return AppColors.primary;
    }
  }

  IconData get _icon {
    if (widget.icon != null) return widget.icon!;
    switch (widget.type) {
      case NotificationType.success:
        return Icons.check_circle;
      case NotificationType.error:
        return Icons.error;
      case NotificationType.warning:
        return Icons.warning;
      case NotificationType.info:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _slideAnimation.value * 100),
            child: Opacity(
              opacity: _fadeAnimation.value,
              child: child,
            ),
          );
        },
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            onTap: _dismiss,
            onVerticalDragEnd: (details) {
              if (details.primaryVelocity != null && details.primaryVelocity! < 0) {
                _dismiss();
              }
            },
            child: Container(
              margin: EdgeInsets.only(
                top: topPadding + 8,
                left: 16,
                right: 16,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: _backgroundColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: _backgroundColor.withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _icon,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _dismiss,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.close,
                        color: Colors.white.withOpacity(0.8),
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
