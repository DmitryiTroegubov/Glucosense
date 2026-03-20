import 'dart:convert';

/// A calibration point linking a measurement to a reference glucose value.
class CalibrationPoint {
  final String id;
  final String modelId;
  final String measurementId; // link to full Measurement record
  final DateTime timestamp;

  // Features used for model fitting
  final double x1;
  final double x2;
  final double pi;
  final double ratioR;

  // Reference glucose from invasive meter (always stored in mmol/L)
  final double referenceGlucose;

  const CalibrationPoint({
    required this.id,
    required this.modelId,
    required this.measurementId,
    required this.timestamp,
    required this.x1,
    required this.x2,
    required this.pi,
    required this.ratioR,
    required this.referenceGlucose,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'modelId': modelId,
        'measurementId': measurementId,
        'timestamp': timestamp.toIso8601String(),
        'x1': x1,
        'x2': x2,
        'pi': pi,
        'ratioR': ratioR,
        'referenceGlucose': referenceGlucose,
      };

  factory CalibrationPoint.fromJson(Map<String, dynamic> json) =>
      CalibrationPoint(
        id: json['id'] as String,
        modelId: json['modelId'] as String,
        measurementId: json['measurementId'] as String? ?? '',
        timestamp: DateTime.parse(json['timestamp'] as String),
        x1: (json['x1'] as num).toDouble(),
        x2: (json['x2'] as num).toDouble(),
        pi: (json['pi'] as num).toDouble(),
        ratioR: (json['ratioR'] as num).toDouble(),
        referenceGlucose: (json['referenceGlucose'] as num).toDouble(),
      );

  String toDbString() => jsonEncode(toJson());

  factory CalibrationPoint.fromDbString(String s) =>
      CalibrationPoint.fromJson(jsonDecode(s) as Map<String, dynamic>);
}
