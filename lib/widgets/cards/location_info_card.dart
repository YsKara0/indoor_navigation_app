import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';

/// Konum bilgisi kartı
/// Kullanıcının mevcut konumunu ve kalitesini gösterir
class LocationInfoCard extends StatelessWidget {
  final UserLocation? location;
  final NavigationRoute? activeRoute;

  const LocationInfoCard({
    super.key,
    this.location,
    this.activeRoute,
  });

  @override
  Widget build(BuildContext context) {
    if (location == null) {
      return _buildNoLocationCard();
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Başlık ve konum kalitesi
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _qualityColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _qualityIcon,
                  color: _qualityColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      location!.currentRoom ?? 'Konum tespit edildi',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${location!.quality.displayName} • ±${location!.accuracy.toStringAsFixed(1)}m',
                      style: TextStyle(
                        fontSize: 12,
                        color: _qualityColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Aktif navigasyon varsa bilgi göster
          if (activeRoute != null) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            _buildNavigationInfo(),
          ],
        ],
      ),
    );
  }

  Widget _buildNoLocationCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.location_searching,
              color: AppColors.warning,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Konum aranıyor...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'BLE sinyalleri taranıyor',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationInfo() {
    return Row(
      children: [
        Expanded(
          child: _InfoItem(
            icon: Icons.flag_outlined,
            label: 'Hedef',
            value: activeRoute!.destinationName,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _InfoItem(
            icon: Icons.straighten,
            label: 'Mesafe',
            value: activeRoute!.formattedDistance,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _InfoItem(
            icon: Icons.timer_outlined,
            label: 'Süre',
            value: activeRoute!.formattedTime,
          ),
        ),
      ],
    );
  }

  Color get _qualityColor {
    if (location == null) return AppColors.warning;

    switch (location!.quality) {
      case LocationQuality.excellent:
        return AppColors.success;
      case LocationQuality.good:
        return AppColors.info;
      case LocationQuality.fair:
        return AppColors.warning;
      case LocationQuality.poor:
        return AppColors.error;
    }
  }

  IconData get _qualityIcon {
    if (location == null) return Icons.location_searching;

    switch (location!.quality) {
      case LocationQuality.excellent:
        return Icons.my_location;
      case LocationQuality.good:
        return Icons.location_on;
      case LocationQuality.fair:
        return Icons.location_on_outlined;
      case LocationQuality.poor:
        return Icons.location_disabled;
    }
  }
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: AppColors.textHint),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textHint,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
