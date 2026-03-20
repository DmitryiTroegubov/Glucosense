import '../core/constants.dart';
import '../core/default_model.dart';
import '../models/personal_model.dart';
import '../models/report_data.dart';

class QualityCheckResult {
  final bool passed;
  final List<String> failures;

  const QualityCheckResult({required this.passed, required this.failures});
}

class PredictionService {
  /// Quality gate: check sensor report against thresholds.
  static QualityCheckResult checkQuality(
    ReportData r, {
    double minCorrelation = AppConstants.defaultMinCorrelation,
    double minPI = AppConstants.defaultMinPI,
    double maxDrift = AppConstants.defaultMaxDrift,
    int minBeats = AppConstants.defaultMinBeats,
    int minSamples = AppConstants.defaultMinSamples,
  }) {
    final failures = <String>[];

    if (r.correlation < minCorrelation) {
      failures.add(
          'Low correlation: ${r.correlation.toStringAsFixed(3)} (min: $minCorrelation)');
    }
    if (r.pi < minPI) {
      failures.add('Low perfusion: ${r.pi.toStringAsFixed(2)} (min: $minPI)');
    }
    if (r.drift.abs() > maxDrift) {
      failures.add(
          'High drift: ${r.drift.toStringAsFixed(0)} (max: ±$maxDrift)');
    }
    if (r.beats < minBeats) {
      failures
          .add('Few heartbeats: ${r.beats} (min: $minBeats)');
    }
    if (r.samples < minSamples) {
      failures
          .add('Low sample count: ${r.samples} (min: $minSamples)');
    }

    return QualityCheckResult(passed: failures.isEmpty, failures: failures);
  }

  /// Predict glucose in mmol/L.
  /// Uses personal model if canPredict, otherwise falls back to built-in default.
  static double? predict(PersonalModel? model, ReportData r) {
    if (model != null && model.canPredict) {
      return model.predict(r.x1, r.x2, r.pi, r.ratio);
    }
    // Built-in default model fallback
    return _predictWithDefault(r.x1, r.x2, r.pi, r.ratio);
  }

  static double _predictWithDefault(
      double x1, double x2, double pi, double ratioR) {
    final bias = DefaultModel.rawBias;
    final weights = DefaultModel.rawWeights;

    final x1DivPi = (pi > 0.001) ? x1 / pi : 0.0;
    final x2DivPi = (pi > 0.001) ? x2 / pi : 0.0;

    double g = bias;
    g += weights[0] * x1;
    g += weights[1] * x2;
    g += weights[2] * pi;
    g += weights[3] * x1DivPi;
    g += weights[4] * x2DivPi;
    g += weights[5] * ratioR;
    return g.clamp(1.0, 30.0);
  }
}
