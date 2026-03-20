import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../models/enums.dart';
import '../providers/app_state.dart';
import '../theme/colors.dart';

class BleConnectScreen extends StatefulWidget {
  const BleConnectScreen({super.key});

  @override
  State<BleConnectScreen> createState() => _BleConnectScreenState();
}

class _BleConnectScreenState extends State<BleConnectScreen> {
  List<BluetoothDevice> _devices = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    // Request Bluetooth & Location permissions
    final statuses = await [
      Permission.location,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
    ].request();

    final granted =
        statuses.values.every((s) => s.isGranted || s.isLimited);
    if (!granted) {
      setState(() {
        _error =
            'Bluetooth and Location permissions required. Please grant them in Settings.';
        _loading = false;
      });
      return;
    }

    try {
      // Check if Bluetooth is genuinely enabled
      final state = await FlutterBluetoothSerial.instance.state;
      if (state != BluetoothState.STATE_ON) {
        final enabled = await FlutterBluetoothSerial.instance.requestEnable();
        if (enabled != true) {
          setState(() {
            _error = 'Bluetooth must be enabled to connect.';
            _loading = false;
          });
          return;
        }
      }

      final appState = context.read<AppStateProvider>();
      final devices = await appState.getPairedDevices();
      if (mounted) {
        setState(() {
          _devices = devices;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load paired devices: $e';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateProvider>();
    final status = appState.connectionStatus;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect Device'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDevices,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStatusBanner(status),
          Expanded(child: _buildBody(appState)),
        ],
      ),
    );
  }

  Widget _buildStatusBanner(BluetoothConnectionStatus status) {
    if (status == BluetoothConnectionStatus.disconnected) {
      return const SizedBox.shrink();
    }

    String msg;
    Color color;
    switch (status) {
      case BluetoothConnectionStatus.connecting:
        msg = 'Connecting...';
        color = AppColors.warning;
        break;
      case BluetoothConnectionStatus.connected:
        msg = 'Connected';
        color = AppColors.success;
        break;
      case BluetoothConnectionStatus.reconnecting:
        msg = 'Reconnecting...';
        color = AppColors.warning;
        break;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      color: color.withOpacity(0.15),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: color, size: 16),
          const SizedBox(width: 8),
          Text(msg,
              style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          if (status == BluetoothConnectionStatus.connected) ...[
            const Spacer(),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Back to App'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBody(AppStateProvider appState) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  color: AppColors.error, size: 48),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                  onPressed: _loadDevices, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    if (_devices.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bluetooth_disabled,
                  size: 56, color: AppColors.textSecondaryLight),
              const SizedBox(height: 16),
              const Text(
                'No paired devices found.',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                'Pair your GlucoSense device via Android Bluetooth Settings first.',
                textAlign: TextAlign.center,
                style:
                    TextStyle(color: AppColors.textSecondaryLight),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadDevices,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            'Paired Bluetooth Devices',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        ..._devices.map((device) => _DeviceTile(
              device: device,
              isConnected: appState.connectionStatus ==
                      BluetoothConnectionStatus.connected &&
                  appState.connectedDevice?.address == device.address,
              onTap: () async {
                final isConnected = appState.connectionStatus ==
                        BluetoothConnectionStatus.connected &&
                    appState.connectedDevice?.address == device.address;
                if (isConnected) {
                  await appState.disconnect();
                } else {
                  try {
                    await appState.connect(device);
                    if (context.mounted &&
                        appState.connectionStatus ==
                            BluetoothConnectionStatus.connected) {
                      Navigator.pop(context);
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to connect. Check if device is on and in range.'),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  }
                }
              },
            )),
      ],
    );
  }
}

class _DeviceTile extends StatelessWidget {
  final BluetoothDevice device;
  final bool isConnected;
  final VoidCallback onTap;

  const _DeviceTile({
    required this.device,
    required this.isConnected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(
          isConnected ? Icons.bluetooth_connected : Icons.bluetooth,
          color: isConnected ? AppColors.success : AppColors.primary,
        ),
        title: Text(
          device.name ?? 'Unknown Device',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(device.address),
        trailing: isConnected
            ? const Chip(
                label: Text('Connected'),
                backgroundColor: AppColors.success,
                labelStyle: TextStyle(color: Colors.white, fontSize: 12),
              )
            : const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}
