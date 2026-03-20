/// Parsed machine-readable report from JSON:{...} line.
/// This is the primary data source for prediction.
class ReportData {
  final double correlation; // Pearson r of IR/Red signals — quality gate
  final double x1;          // log10(IR_DC) — feature
  final double x2;          // log10(Red_DC/IR_DC) — feature
  final double pi;          // Perfusion Index — feature
  final double ratio;       // Red_PI / IR_PI (Ratio_R) — feature
  final double spo2;        // Estimated SpO2 %
  final double sdnn;        // Heart rate variability ms
  final double acPP;        // IR AC peak-to-peak amplitude
  final double drift;       // DC baseline drift — quality gate
  final int bpm;
  final int beats;          // Heartbeats in window — quality gate
  final int clipping;       // ADC clipping events
  final int samples;        // Total samples — quality gate

  final String rawJsonLine; // Full JSON:{...} line for storage/debug
  String? rawCsvLine;       // CSV copy line if captured

  ReportData({
    required this.correlation,
    required this.x1,
    required this.x2,
    required this.pi,
    required this.ratio,
    required this.spo2,
    required this.sdnn,
    required this.acPP,
    required this.drift,
    required this.bpm,
    required this.beats,
    required this.clipping,
    required this.samples,
    required this.rawJsonLine,
    this.rawCsvLine,
  });

  factory ReportData.fromJson(Map<String, dynamic> json, String rawLine) {
    return ReportData(
      correlation: (json['correlation'] as num).toDouble(),
      x1: (json['X1'] as num).toDouble(),
      x2: (json['X2'] as num).toDouble(),
      pi: (json['PI'] as num).toDouble(),
      ratio: (json['ratio'] as num).toDouble(),
      spo2: (json['spo2'] as num).toDouble(),
      sdnn: (json['sdnn'] as num).toDouble(),
      acPP: (json['AC_pp'] as num).toDouble(),
      drift: (json['drift'] as num).toDouble(),
      bpm: (json['bpm'] as num).toInt(),
      beats: (json['beats'] as num).toInt(),
      clipping: (json['clipping'] as num? ?? 0).toInt(),
      samples: (json['samples'] as num).toInt(),
      rawJsonLine: rawLine,
    );
  }
}
