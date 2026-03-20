import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/enums.dart';
import '../providers/app_state.dart';
import '../theme/colors.dart';

class ConnectionBar extends StatelessWidget {
  const ConnectionBar({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateProvider>();
    final status = appState.connectionStatus;
    final deviceName = appState.connectedDevice?.name ?? 'Not connected';

    Color color;
    IconData icon;
    String label;

    switch (status) {
      case BluetoothConnectionStatus.connected:
        color = AppColors.success;
        icon = Icons.bluetooth_connected;
        label = deviceName;
        break;
      case BluetoothConnectionStatus.connecting:
        color = AppColors.warning;
        icon = Icons.bluetooth_searching;
        label = 'Connecting...';
        break;
      case BluetoothConnectionStatus.reconnecting:
        color = AppColors.warning;
        icon = Icons.bluetooth_searching;
        label = 'Reconnecting...';
        break;
      case BluetoothConnectionStatus.disconnected:
        color = AppColors.error;
        icon = Icons.bluetooth_disabled;
        label = 'Disconnected';
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border(
          bottom: BorderSide(color: color.withOpacity(0.3), width: 1),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (status == BluetoothConnectionStatus.connected)
            _StateChip(appState.measurementState),
        ],
      ),
    );
  }
}

class _StateChip extends StatelessWidget {
  final AppState state;
  const _StateChip(this.state);

  @override
  Widget build(BuildContext context) {
    String label;
    Color color;

    switch (state) {
      case AppState.disconnected:
        label = 'DISCONNECTED';
        color = AppColors.textSecondaryLight;
        break;
      case AppState.idle:
        label = 'IDLE';
        color = AppColors.textSecondaryLight;
        break;
      case AppState.stabilizing:
        label = 'STABILIZING';
        color = AppColors.primary;
        break;
      case AppState.collecting:
        label = 'COLLECTING';
        color = AppColors.warning;
        break;
      case AppState.result:
        label = 'RESULT';
        color = AppColors.success;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
