import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import '../core/constants.dart';
import '../models/enums.dart';

class BluetoothService {
  BluetoothConnection? _connection;
  StreamSubscription? _inputSub;
  Timer? _reconnectTimer;

  final _statusController =
      StreamController<BluetoothConnectionStatus>.broadcast();
  final _dataController = StreamController<String>.broadcast();

  Stream<BluetoothConnectionStatus> get statusStream => _statusController.stream;
  Stream<String> get dataStream => _dataController.stream;

  BluetoothConnectionStatus _status = BluetoothConnectionStatus.disconnected;
  BluetoothConnectionStatus get status => _status;

  BluetoothDevice? _lastDevice;
  int _reconnectAttempt = 0;

  void _emit(BluetoothConnectionStatus s) {
    _status = s;
    _statusController.add(s);
  }

  // ─── Scan ─────────────────────────────────────────────────────────────────

  /// Returns all paired Bluetooth devices.
  Future<List<BluetoothDevice>> getPairedDevices() async {
    try {
      return await FlutterBluetoothSerial.instance.getBondedDevices();
    } catch (_) {
      return [];
    }
  }

  // ─── Connect ──────────────────────────────────────────────────────────────

  Future<void> connect(BluetoothDevice device) async {
    if (_status == BluetoothConnectionStatus.connected ||
        _status == BluetoothConnectionStatus.connecting) {
      return;
    }

    _lastDevice = device;
    _reconnectAttempt = 0;
    try {
      await _doConnect(device);
    } catch (e) {
      _lastDevice = null;
      _emit(BluetoothConnectionStatus.disconnected);
      rethrow;
    }
  }

  Future<void> _doConnect(BluetoothDevice device) async {
    _emit(BluetoothConnectionStatus.connecting);
    try {
      final conn = await BluetoothConnection.toAddress(device.address)
          .timeout(const Duration(seconds: 15));
      _connection = conn;
      _reconnectAttempt = 0;
      _emit(BluetoothConnectionStatus.connected);

      String buffer = '';
      _inputSub = conn.input!.listen(
        (Uint8List data) {
          buffer += String.fromCharCodes(data);
          final lines = buffer.split('\n');
          buffer = lines.removeLast();
          for (final line in lines) {
            _dataController.add('$line\n');
          }
        },
        onDone: _onDisconnected,
        onError: (_) => _onDisconnected(),
        cancelOnError: false,
      );
    } catch (e) {
      if (_reconnectAttempt == 0) {
        _connection?.dispose();
        _connection = null;
        throw e;
      } else {
        _onDisconnected();
      }
    }
  }

  void _onDisconnected() {
    _inputSub?.cancel();
    _inputSub = null;
    _connection?.dispose();
    _connection = null;

    if (_lastDevice == null) {
      _emit(BluetoothConnectionStatus.disconnected);
      return;
    }

    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _emit(BluetoothConnectionStatus.reconnecting);
    _reconnectTimer?.cancel();

    final delays = AppConstants.reconnectBackoff;
    final delaySeconds =
        delays[_reconnectAttempt.clamp(0, delays.length - 1)];
    _reconnectAttempt++;

    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      if (_lastDevice != null &&
          _status == BluetoothConnectionStatus.reconnecting) {
        _doConnect(_lastDevice!);
      }
    });
  }

  // ─── Disconnect ───────────────────────────────────────────────────────────

  Future<void> disconnect() async {
    _lastDevice = null;
    _reconnectTimer?.cancel();
    _inputSub?.cancel();
    _inputSub = null;
    await _connection?.close();
    _connection?.dispose();
    _connection = null;
    _emit(BluetoothConnectionStatus.disconnected);
  }

  // ─── Cleanup ──────────────────────────────────────────────────────────────

  void dispose() {
    disconnect();
    _statusController.close();
    _dataController.close();
  }
}
