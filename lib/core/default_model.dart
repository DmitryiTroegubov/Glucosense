/// Built-in pre-trained model coefficients.
/// Replace rawBias and rawWeights with actual values from new_clark.py:
/// Look for the "READY CODE FOR ARDUINO / ESP32" section and copy
/// float raw_bias and float raw_weights[6].
class DefaultModel {
  static const String id = 'built-in-default';
  static const String name = 'Default Model';

  /// De-normalized bias (intercept). Replace with actual value.
  static const double rawBias = 0.0;

  /// De-normalized weights [X1, X2, PI, X1/PI, X2/PI, Ratio_R]. Replace with actual values.
  static const List<double> rawWeights = [
    0.0, // X1 coefficient
    0.0, // X2 coefficient
    0.0, // PI coefficient
    0.0, // X1/PI coefficient
    0.0, // X2/PI coefficient
    0.0, // Ratio_R coefficient
  ];
}
