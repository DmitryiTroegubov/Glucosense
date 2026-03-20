import 'dart:convert';

/// A full measurement record. Saved automatically after every JSON report.
class Measurement {
  final String id;
  final DateTime timestamp;
  final String modelId; // which model was active

  // Raw sensor data (all fields from JSON report)
  final double x1;
  final double x2;
  final double pi;
  final double ratioR;
  final double correlation;
  final double spo2;
  final int bpm;
  final double sdnn;
  final double acPP;
  final double drift;
  final int beats;
  final int clipping;
  final int samples;

  // Prediction result
  final double? predictedGlucose; // null if quality rejected
  final bool qualityPassed;
  final List<String> qualityFailures; // empty if passed

  // Calibration (set later by user)
  final double? referenceGlucose; // mmol/L, null until user enters value

  // Raw lines for debugging / export
  final String rawJsonLine;
  final String? rawCsvLine;

  const Measurement({
    required this.id,
    required this.timestamp,
    required this.modelId,
    required this.x1,
    required this.x2,
    required this.pi,
    required this.ratioR,
    required this.correlation,
    required this.spo2,
    required this.bpm,
    required this.sdnn,
    required this.acPP,
    required this.drift,
    required this.beats,
    required this.clipping,
    required this.samples,
    this.predictedGlucose,
    required this.qualityPassed,
    required this.qualityFailures,
    this.referenceGlucose,
    required this.rawJsonLine,
    this.rawCsvLine,
  });

  Measurement copyWith({double? referenceGlucose, String? rawCsvLine}) {
    return Measurement(
      id: id,
      timestamp: timestamp,
      modelId: modelId,
      x1: x1,
      x2: x2,
      pi: pi,
      ratioR: ratioR,
      correlation: correlation,
      spo2: spo2,
      bpm: bpm,
      sdnn: sdnn,
      acPP: acPP,
      drift: drift,
      beats: beats,
      clipping: clipping,
      samples: samples,
      predictedGlucose: predictedGlucose,
      qualityPassed: qualityPassed,
      qualityFailures: qualityFailures,
      referenceGlucose: referenceGlucose ?? this.referenceGlucose,
      rawJsonLine: rawJsonLine,
      rawCsvLine: rawCsvLine ?? this.rawCsvLine,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'modelId': modelId,
        'x1': x1,
        'x2': x2,
        'pi': pi,
        'ratioR': ratioR,
        'correlation': correlation,
        'spo2': spo2,
        'bpm': bpm,
        'sdnn': sdnn,
        'acPP': acPP,
        'drift': drift,
        'beats': beats,
        'clipping': clipping,
        'samples': samples,
        'predictedGlucose': predictedGlucose,
        'qualityPassed': qualityPassed,
        'qualityFailures': qualityFailures,
        'referenceGlucose': referenceGlucose,
        'rawJsonLine': rawJsonLine,
        'rawCsvLine': rawCsvLine,
      };

  factory Measurement.fromJson(Map<String, dynamic> json) => Measurement(
        id: json['id'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        modelId: json['modelId'] as String? ?? '',
        x1: (json['x1'] as num).toDouble(),
        x2: (json['x2'] as num).toDouble(),
        pi: (json['pi'] as num).toDouble(),
        ratioR: (json['ratioR'] as num).toDouble(),
        correlation: (json['correlation'] as num).toDouble(),
        spo2: (json['spo2'] as num).toDouble(),
        bpm: (json['bpm'] as num).toInt(),
        sdnn: (json['sdnn'] as num).toDouble(),
        acPP: (json['acPP'] as num).toDouble(),
        drift: (json['drift'] as num).toDouble(),
        beats: (json['beats'] as num).toInt(),
        clipping: (json['clipping'] as num? ?? 0).toInt(),
        samples: (json['samples'] as num).toInt(),
        predictedGlucose: (json['predictedGlucose'] as num?)?.toDouble(),
        qualityPassed: json['qualityPassed'] as bool? ?? false,
        qualityFailures: (json['qualityFailures'] as List<dynamic>? ?? [])
            .map((e) => e as String)
            .toList(),
        referenceGlucose: (json['referenceGlucose'] as num?)?.toDouble(),
        rawJsonLine: json['rawJsonLine'] as String? ?? '',
        rawCsvLine: json['rawCsvLine'] as String?,
      );

  String toDbString() => jsonEncode(toJson());

  factory Measurement.fromDbString(String s) =>
      Measurement.fromJson(jsonDecode(s) as Map<String, dynamic>);

  String toCsvRow(bool useMgdl) {
    final factor = useMgdl ? 18.018 : 1.0;
    final pred = predictedGlucose != null
        ? (predictedGlucose! * factor).toStringAsFixed(2)
        : '';
    final ref = referenceGlucose != null
        ? (referenceGlucose! * factor).toStringAsFixed(2)
        : '';
    return [
      timestamp.toIso8601String(),
      modelId,
      qualityPassed ? 'PASS' : 'REJECT',
      pred,
      ref,
      x1.toStringAsFixed(4),
      x2.toStringAsFixed(4),
      pi.toStringAsFixed(4),
      ratioR.toStringAsFixed(4),
      correlation.toStringAsFixed(4),
      spo2.toStringAsFixed(1),
      bpm,
      sdnn.toStringAsFixed(1),
      drift.toStringAsFixed(0),
      beats,
      samples,
    ].join(',');
  }

  static String csvHeader(bool useMgdl) {
    final unit = useMgdl ? 'mg/dL' : 'mmol/L';
    return 'timestamp,modelId,quality,predicted_$unit,reference_$unit,'
        'x1,x2,pi,ratioR,correlation,spo2,bpm,sdnn,drift,beats,samples';
  }
}
