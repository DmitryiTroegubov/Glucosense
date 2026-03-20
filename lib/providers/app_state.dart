import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../core/constants.dart';
import '../models/enums.dart';
import '../models/live_data.dart';
import '../models/measurement.dart';
import '../models/report_data.dart';
import '../services/bluetooth_service.dart';
import '../services/serial_parser.dart';
import '../services/prediction_service.dart';
import '../models/personal_model.dart';
import '../services/storage_service.dart';
import 'model_provider.dart';
import 'settings_provider.dart';

/// Central application state provider.
/// Manages Bluetooth connection, measurement state machine, live data,
/// history cache, and serial monitor log.
class AppStateProvider extends ChangeNotifier {
  final BluetoothService _bt = BluetoothService();
  final SerialParser _parser = SerialParser();
  final StorageService _storage = StorageService();
  final _uuid = const Uuid();

  StreamSubscription<String>? _lineSub;
  StreamSubscription<BluetoothConnectionStatus>? _statusSub;

  // ─── Bluetooth state ───────────────────────────────────────────────────────

  BluetoothConnectionStatus get connectionStatus => _bt.status;
  BluetoothDevice? _connectedDevice;
  BluetoothDevice? get connectedDevice => _connectedDevice;

  // ─── App state machine ─────────────────────────────────────────────────────

  AppState _measurementState = AppState.disconnected;
  AppState get measurementState => _measurementState;

  // ─── Live data ─────────────────────────────────────────────────────────────

  LiveData? _liveData;
  LiveData? get liveData => _liveData;

  final List<int> _irACBuffer = [];
  List<int> get irACBuffer => List.unmodifiable(_irACBuffer);

  // ─── Current result ────────────────────────────────────────────────────────

  ReportData? _currentReport;
  ReportData? get currentReport => _currentReport;

  double? _currentGlucose;
  double? get currentGlucose => _currentGlucose;

  QualityCheckResult? _currentQuality;
  QualityCheckResult? get currentQuality => _currentQuality;

  // Last saved measurement (for CSV line attachment)
  Measurement? _lastSavedMeasurement;

  // ─── History ───────────────────────────────────────────────────────────────

  List<Measurement> _measurements = [];
  List<Measurement> get measurements => List.unmodifiable(_measurements);

  // ─── Serial monitor ────────────────────────────────────────────────────────

  final List<String> _serialLog = [];
  List<String> get serialLog => List.unmodifiable(_serialLog);

  final _dateFmt = DateFormat('HH:mm:ss.SSS');

  // ─── Active model ──────────────────────────────────────────────────────────

  String? _activeModelId;

  // Settings ref (injected at wire-up time)
  SettingsProvider? _settings;

  AppStateProvider() {
    _init();
  }

  Future<void> _init() async {
    _measurements = await _storage.getAllMeasurements();
    _statusSub = _bt.statusStream.listen(_onBtStatus);
    notifyListeners();
  }

  void wireSettings(SettingsProvider settings) {
    _settings = settings;
  }

  // ─── Bluetooth ─────────────────────────────────────────────────────────────

  Future<List<BluetoothDevice>> getPairedDevices() =>
      _bt.getPairedDevices();

  Future<void> connect(BluetoothDevice device) async {
    _connectedDevice = device;
    await _bt.connect(device);
    _lineSub?.cancel();
    _lineSub = _bt.dataStream.listen(_onLine);
  }

  Future<void> disconnect() async {
    _lineSub?.cancel();
    _lineSub = null;
    _connectedDevice = null;
    await _bt.disconnect();
    _setState(AppState.disconnected);
  }

  void _onBtStatus(BluetoothConnectionStatus status) {
    if (status == BluetoothConnectionStatus.disconnected ||
        status == BluetoothConnectionStatus.reconnecting) {
      if (_measurementState != AppState.disconnected) {
        _setState(AppState.disconnected);
      }
      if (status == BluetoothConnectionStatus.connected) {
        if (_measurementState == AppState.disconnected) {
          _setState(AppState.idle);
        }
      }
    } else if (status == BluetoothConnectionStatus.connected) {
      if (_measurementState == AppState.disconnected) {
        _setState(AppState.idle);
      }
    }
    notifyListeners();
  }

  // ─── Line processing ───────────────────────────────────────────────────────

  void _onLine(String rawLine) {
    final line = rawLine.trimRight();
    // Serial log with timestamp
    final entry = '[${_dateFmt.format(DateTime.now())}] $line';
    _serialLog.add(entry);
    if (_serialLog.length > AppConstants.maxSerialLines) {
      _serialLog.removeAt(0);
    }

    final event = _parser.parseLine(line);
    _routeEvent(event);
    notifyListeners();
  }

  void _routeEvent(ParsedEvent event) {
    switch (event) {
      case LiveDataEvent(:final data):
        _liveData = data;
        // Update state from phase
        if (data.phase == 'collecting' &&
            _measurementState == AppState.stabilizing) {
          _measurementState = AppState.collecting;
        } else if (data.phase == 'stabilizing' &&
            _measurementState == AppState.idle) {
          _measurementState = AppState.stabilizing;
        }
        // Append to waveform buffer
        _irACBuffer.add(data.irAC);
        if (_irACBuffer.length > AppConstants.irACBufferSize) {
          _irACBuffer.removeAt(0);
        }

      case ReportEvent(:final data):
        _handleReport(data);

      case StatusEvent(:final type):
        _handleStatus(type);

      case CsvLineEvent(:final line):
        // Attach CSV line to the last saved measurement
        if (_lastSavedMeasurement != null && line.contains(',')) {
          final updated =
              _lastSavedMeasurement!.copyWith(rawCsvLine: line);
          _lastSavedMeasurement = updated;
          _storage.updateMeasurement(updated);
          // Update in-memory list
          final idx =
              _measurements.indexWhere((m) => m.id == updated.id);
          if (idx >= 0) _measurements[idx] = updated;
        }

      case RawLineEvent():
        break; // logged above, no state change
    }
  }

  void _handleStatus(StatusType type) {
    switch (type) {
      case StatusType.fingerDetected:
        _liveData = null;
        _irACBuffer.clear();
        _currentReport = null;
        _currentGlucose = null;
        _currentQuality = null;
        _setState(AppState.stabilizing);
      case StatusType.noFinger:
        _setState(AppState.idle);
      case StatusType.sensorError:
      case StatusType.notEnoughSamples:
        _setState(AppState.idle);
      case StatusType.systemStart:
        if (_measurementState == AppState.disconnected) {
          _setState(AppState.idle);
        }
    }
  }

  void _handleReport(ReportData report) {
    final settings = _settings;
    final quality = PredictionService.checkQuality(
      report,
      minCorrelation: settings?.minCorrelation ??
          AppConstants.defaultMinCorrelation,
      minPI: settings?.minPI ?? AppConstants.defaultMinPI,
      maxDrift: settings?.maxDrift ?? AppConstants.defaultMaxDrift,
      minBeats: settings?.minBeats ?? AppConstants.defaultMinBeats,
      minSamples: settings?.minSamples ?? AppConstants.defaultMinSamples,
    );

    _currentReport = report;
    _currentQuality = quality;

    double? glucose;
    if (quality.passed) {
      // Predict — model provider is accessed via context in screens,
      // so prediction uses the active model ID stored here.
      glucose = PredictionService.predict(null, report); // default model
    }
    _currentGlucose = glucose;

    // Save measurement to Hive
    final m = Measurement(
      id: _uuid.v4(),
      timestamp: DateTime.now(),
      modelId: _activeModelId ?? '',
      x1: report.x1,
      x2: report.x2,
      pi: report.pi,
      ratioR: report.ratio,
      correlation: report.correlation,
      spo2: report.spo2,
      bpm: report.bpm,
      sdnn: report.sdnn,
      acPP: report.acPP,
      drift: report.drift,
      beats: report.beats,
      clipping: report.clipping,
      samples: report.samples,
      predictedGlucose: glucose,
      qualityPassed: quality.passed,
      qualityFailures: quality.failures,
      rawJsonLine: report.rawJsonLine,
    );
    _lastSavedMeasurement = m;
    _measurements.insert(0, m);
    _storage.saveMeasurement(m);

    HapticFeedback.mediumImpact();
    _setState(AppState.result);
  }

  /// Called by screens to set active personal model for predictions.
  void setActiveModel(String? modelId) {
    _activeModelId = modelId;
  }

  /// Predict using a specific model (called from screens that have model context).
  void updatePredictionWithModel(PersonalModel? model) {
    if (_currentReport == null || !(_currentQuality?.passed ?? false)) return;
    _currentGlucose = PredictionService.predict(model, _currentReport!);
    // Update the saved measurement
    if (_lastSavedMeasurement != null && _currentGlucose != null) {
      final updated = Measurement(
        id: _lastSavedMeasurement!.id,
        timestamp: _lastSavedMeasurement!.timestamp,
        modelId: model?.id ?? '',
        x1: _lastSavedMeasurement!.x1,
        x2: _lastSavedMeasurement!.x2,
        pi: _lastSavedMeasurement!.pi,
        ratioR: _lastSavedMeasurement!.ratioR,
        correlation: _lastSavedMeasurement!.correlation,
        spo2: _lastSavedMeasurement!.spo2,
        bpm: _lastSavedMeasurement!.bpm,
        sdnn: _lastSavedMeasurement!.sdnn,
        acPP: _lastSavedMeasurement!.acPP,
        drift: _lastSavedMeasurement!.drift,
        beats: _lastSavedMeasurement!.beats,
        clipping: _lastSavedMeasurement!.clipping,
        samples: _lastSavedMeasurement!.samples,
        predictedGlucose: _currentGlucose,
        qualityPassed: _lastSavedMeasurement!.qualityPassed,
        qualityFailures: _lastSavedMeasurement!.qualityFailures,
        rawJsonLine: _lastSavedMeasurement!.rawJsonLine,
        rawCsvLine: _lastSavedMeasurement!.rawCsvLine,
      );
      _lastSavedMeasurement = updated;
      final idx = _measurements.indexWhere((m) => m.id == updated.id);
      if (idx >= 0) _measurements[idx] = updated;
      _storage.updateMeasurement(updated);
    }
    notifyListeners();
  }

  /// Dismiss the result screen, return to idle.
  void dismissResult() {
    _currentReport = null;
    _currentGlucose = null;
    _currentQuality = null;
    _setState(AppState.idle);
  }

  /// Save current measurement's reference glucose and create a calibration point.
  Future<void> saveToCalibration(
      double referenceGlucoseMmol, ModelProvider modelProvider) async {
    final m = _lastSavedMeasurement;
    if (m == null) return;

    // Update measurement with reference glucose
    final updated = m.copyWith(referenceGlucose: referenceGlucoseMmol);
    _lastSavedMeasurement = updated;
    final idx = _measurements.indexWhere((meas) => meas.id == updated.id);
    if (idx >= 0) _measurements[idx] = updated;
    await _storage.updateMeasurement(updated);

    // Create calibration point on active model
    await modelProvider.addCalibrationPoint(
      measurementId: m.id,
      x1: m.x1,
      x2: m.x2,
      pi: m.pi,
      ratioR: m.ratioR,
      referenceGlucose: referenceGlucoseMmol,
    );

    notifyListeners();
  }

  // ─── History management ────────────────────────────────────────────────────

  Future<void> clearAllHistory() async {
    await _storage.clearAllMeasurements();
    _measurements = [];
    _lastSavedMeasurement = null;
    notifyListeners();
  }

  // ─── Serial log ────────────────────────────────────────────────────────────

  void clearSerialLog() {
    _serialLog.clear();
    notifyListeners();
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  void _setState(AppState state) {
    _measurementState = state;
  }

  @override
  void dispose() {
    _lineSub?.cancel();
    _statusSub?.cancel();
    _bt.dispose();
    super.dispose();
  }
}
