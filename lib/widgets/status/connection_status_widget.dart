import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../services/websocket/websocket.dart';
import '../../services/ble/ble_service.dart';

/// Bağlantı durumu göstergesi
/// WebSocket ve BLE bağlantı durumlarını gösterir
class ConnectionStatusWidget extends StatelessWidget {
  final WebSocketConnectionState wsState;
  final BleScanState bleState;
  final VoidCallback? onRetry;

  const ConnectionStatusWidget({
    super.key,
    required this.wsState,
    required this.bleState,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // WebSocket durumu
          _StatusIndicator(
            icon: Icons.cloud,
            label: 'WS',
            status: _wsStatusToGeneric(wsState),
          ),
          const SizedBox(width: 6),
          // BLE durumu
          _StatusIndicator(
            icon: Icons.bluetooth,
            label: 'BLE',
            status: _bleStatusToGeneric(bleState),
          ),
          // Yeniden deneme butonu
          if (_showRetryButton) ...[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onRetry,
              child: const Icon(Icons.refresh, size: 14, color: AppColors.primary),
            ),
          ],
        ],
      ),
    );
  }

  bool get _showRetryButton =>
      wsState == WebSocketConnectionState.error ||
      wsState == WebSocketConnectionState.disconnected ||
      bleState == BleScanState.error;

  _ConnectionStatus _wsStatusToGeneric(WebSocketConnectionState state) {
    switch (state) {
      case WebSocketConnectionState.connected:
        return _ConnectionStatus.connected;
      case WebSocketConnectionState.connecting:
      case WebSocketConnectionState.reconnecting:
        return _ConnectionStatus.connecting;
      case WebSocketConnectionState.disconnected:
        return _ConnectionStatus.disconnected;
      case WebSocketConnectionState.error:
        return _ConnectionStatus.error;
    }
  }

  _ConnectionStatus _bleStatusToGeneric(BleScanState state) {
    switch (state) {
      case BleScanState.scanning:
        return _ConnectionStatus.connected;
      case BleScanState.idle:
      case BleScanState.stopped:
        return _ConnectionStatus.disconnected;
      case BleScanState.error:
      case BleScanState.bluetoothOff:
      case BleScanState.noPermission:
        return _ConnectionStatus.error;
    }
  }
}

enum _ConnectionStatus { connected, connecting, disconnected, error }

class _StatusIndicator extends StatelessWidget {
  final IconData icon;
  final String label;
  final _ConnectionStatus status;

  const _StatusIndicator({
    required this.icon,
    required this.label,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _statusColor,
          ),
        ),
        const SizedBox(width: 3),
        Icon(icon, size: 12, color: AppColors.textSecondary),
      ],
    );
  }

  Color get _statusColor {
    switch (status) {
      case _ConnectionStatus.connected:
        return AppColors.success;
      case _ConnectionStatus.connecting:
        return AppColors.warning;
      case _ConnectionStatus.disconnected:
        return AppColors.textHint;
      case _ConnectionStatus.error:
        return AppColors.error;
    }
  }
}
