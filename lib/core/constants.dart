class AppConstants {
  // Device
  static const String defaultDeviceName = 'GlucoSense';

  // Quality thresholds (defaults — user-editable in settings)
  static const double defaultMinCorrelation = 0.70;
  static const double defaultMinPI = 1.0;
  static const double defaultMaxDrift = 1500.0;
  static const int defaultMinBeats = 2;
  static const int defaultMinSamples = 50;

  // Model constraints
  static const int minCalibrationPoints = 8;

  // Measurement cycle timing (seconds)
  static const int stabilizationSeconds = 20;
  static const int collectionSeconds = 5;
  static const int measurementWindowSeconds = 25;

  // Deduplication window (seconds)
  static const int deduplicationSeconds = 3;

  // Regression
  static const double huberEpsilon = 1.35;
  static const int huberMaxIterations = 50;
  static const double huberConvergenceThreshold = 1e-6;

  // Auto-reconnect backoff (seconds)
  static const List<int> reconnectBackoff = [1, 2, 4, 8, 10];

  // Serial monitor max lines
  static const int maxSerialLines = 3000;

  // IR_AC buffer size for waveform
  static const int irACBufferSize = 60;

  // History chart max points
  static const int chartMaxPoints = 50;

  // Units
  static const double mmolToMgdl = 18.018;

  // Hive box names
  static const String boxMeasurements = 'measurements';
  static const String boxModels = 'models';
  static const String boxCalibrationPoints = 'calibrationPoints';
}
