import 'dart:math' show pow, sqrt, max;
import '../core/constants.dart';
import '../models/calibration_point.dart';
import '../utils/matrix_math.dart';

/// Result of a full model fit: de-normalized coefficients + scaler params.
class FitResult {
  final double rawBias;
  final List<double> rawWeights; // length 6
  final List<double> scalerMeans; // length 6
  final List<double> scalerStds; // length 6
  final double mard; // Mean Absolute Relative Difference %
  final double rmse;

  const FitResult({
    required this.rawBias,
    required this.rawWeights,
    required this.scalerMeans,
    required this.scalerStds,
    required this.mard,
    required this.rmse,
  });
}

/// Regression service: 6-feature StandardScaler + Huber IRLS pipeline.
///
/// Feature order: [X1, X2, PI, X1/PI, X2/PI, Ratio_R]
/// Matches new_clark.py: Pipeline([StandardScaler, HuberRegressor])
///
/// The fit produces de-normalized (raw) weights so inference needs no scaler:
///   glucose = rawBias + Σ(rawWeights[i] × feature[i])
class RegressionService {
  static const int _numFeatures = 6;

  // ─── Feature construction ──────────────────────────────────────────────────

  /// Build a 6-element feature vector from raw sensor values.
  static List<double> buildFeatures(
      double x1, double x2, double pi, double ratioR) {
    final x1DivPi = (pi > 0.001) ? x1 / pi : 0.0;
    final x2DivPi = (pi > 0.001) ? x2 / pi : 0.0;
    return [x1, x2, pi, x1DivPi, x2DivPi, ratioR];
  }

  // ─── Full fit pipeline ─────────────────────────────────────────────────────

  /// Fit a model from calibration points.
  /// Returns null if too few points or matrix is singular.
  static FitResult? fit(List<CalibrationPoint> points) {
    final n = points.length;
    if (n < AppConstants.minCalibrationPoints) return null;

    // 1. Build raw feature matrix [n × 6] and target vector [n]
    final rawFeatures = points
        .map((p) => buildFeatures(p.x1, p.x2, p.pi, p.ratioR))
        .toList();
    final targets = points.map((p) => p.referenceGlucose).toList();

    // 2. Compute per-column mean and population std
    final means = List.filled(_numFeatures, 0.0);
    final stds = List.filled(_numFeatures, 1.0);

    for (int j = 0; j < _numFeatures; j++) {
      double sum = 0;
      for (int i = 0; i < n; i++) sum += rawFeatures[i][j];
      means[j] = sum / n;

      double varSum = 0;
      for (int i = 0; i < n; i++) {
        varSum += pow(rawFeatures[i][j] - means[j], 2).toDouble();
      }
      final std = sqrt(varSum / n); // population std (matches sklearn default)
      stds[j] = std < 1e-10 ? 1.0 : std;
    }

    // 3. Standardize features
    final scaledFeatures = rawFeatures.map((row) {
      return List.generate(_numFeatures, (j) => (row[j] - means[j]) / stds[j]);
    }).toList();

    // 4. Fit Huber IRLS, fall back to OLS
    var beta = _fitHuberIRLS(scaledFeatures, targets);
    beta ??= _solveOLS(scaledFeatures, targets);
    if (beta == null) return null;

    // beta[0] = intercept, beta[1..6] = feature weights (on scaled features)
    final scaledWeights = beta.sublist(1); // length 6
    final scaledBias = beta[0];

    // 5. De-normalize so raw features can be used directly at inference
    final rawWeights =
        List.generate(_numFeatures, (j) => scaledWeights[j] / stds[j]);
    double rawBias = scaledBias;
    for (int j = 0; j < _numFeatures; j++) {
      rawBias -= (scaledWeights[j] * means[j]) / stds[j];
    }

    // 6. Compute training metrics
    final predicted = rawFeatures.map((f) {
      double g = rawBias;
      for (int j = 0; j < _numFeatures; j++) g += rawWeights[j] * f[j];
      return g.clamp(1.0, 30.0);
    }).toList();

    return FitResult(
      rawBias: rawBias,
      rawWeights: rawWeights,
      scalerMeans: means,
      scalerStds: stds,
      mard: _calculateMARD(predicted, targets),
      rmse: _calculateRMSE(predicted, targets),
    );
  }

  // ─── Huber IRLS ────────────────────────────────────────────────────────────

  static List<double>? _fitHuberIRLS(
    List<List<double>> x,
    List<double> y, {
    double epsilon = AppConstants.huberEpsilon,
    int maxIter = AppConstants.huberMaxIterations,
  }) {
    final n = x.length;
    var w = List.filled(n, 1.0);

    var beta = _solveWeightedOLS(x, y, w);
    if (beta == null) return null;

    for (int iter = 0; iter < maxIter; iter++) {
      final residuals = List.generate(n, (i) {
        double pred = beta![0];
        for (int j = 0; j < _numFeatures; j++) pred += beta[j + 1] * x[i][j];
        return y[i] - pred;
      });

      final absRes = residuals.map((r) => r.abs()).toList()..sort();
      double sigma = absRes[n ~/ 2] / 0.6745;
      if (sigma < 1e-10) sigma = 1e-10;

      double maxChange = 0;
      final newW = List.generate(n, (i) {
        final r = (residuals[i] / sigma).abs();
        return r <= epsilon ? 1.0 : epsilon / r;
      });
      for (int i = 0; i < n; i++) {
        maxChange = max(maxChange, (newW[i] - w[i]).abs());
      }
      w = newW;

      final newBeta = _solveWeightedOLS(x, y, w);
      if (newBeta == null) return beta;
      beta = newBeta;

      if (maxChange < AppConstants.huberConvergenceThreshold) break;
    }
    return beta;
  }

  // ─── Weighted OLS ──────────────────────────────────────────────────────────

  static List<double>? _solveWeightedOLS(
    List<List<double>> x,
    List<double> y,
    List<double> weights,
  ) {
    final n = x.length;
    final p = _numFeatures + 1;
    final xd = List.generate(n, (i) => [1.0, ...x[i]]);

    final xtwx = List.generate(p, (_) => List.filled(p, 0.0));
    final xtwy = List.filled(p, 0.0);

    for (int i = 0; i < n; i++) {
      for (int j = 0; j < p; j++) {
        for (int k = 0; k < p; k++) {
          xtwx[j][k] += weights[i] * xd[i][j] * xd[i][k];
        }
        xtwy[j] += weights[i] * xd[i][j] * y[i];
      }
    }

    final inv = MatrixMath.invert(xtwx);
    if (inv == null) return null;
    return MatrixMath.multiplyVec(inv, xtwy);
  }

  static List<double>? _solveOLS(List<List<double>> x, List<double> y) {
    return _solveWeightedOLS(x, y, List.filled(x.length, 1.0));
  }

  // ─── Metrics ───────────────────────────────────────────────────────────────

  static double _calculateMARD(List<double> predicted, List<double> reference) {
    if (predicted.isEmpty) return 0.0;
    double sum = 0;
    for (int i = 0; i < predicted.length; i++) {
      if (reference[i] != 0) sum += (predicted[i] - reference[i]).abs() / reference[i];
    }
    return (sum / predicted.length) * 100.0;
  }

  static double _calculateRMSE(List<double> predicted, List<double> reference) {
    if (predicted.isEmpty) return 0.0;
    double sum = 0;
    for (int i = 0; i < predicted.length; i++) {
      final diff = predicted[i] - reference[i];
      sum += diff * diff;
    }
    final mean = sum / predicted.length;
    return mean > 0 ? sqrt(mean) : 0.0;
  }
}
