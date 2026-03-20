import 'dart:convert';
import '../core/constants.dart';
import '../core/default_model.dart';

/// A personal glucose prediction model.
class PersonalModel {
  final String id;
  final String name;
  final bool isDefault; // true for built-in model (cannot delete)
  final DateTime createdAt;
  final DateTime updatedAt;

  // De-normalized coefficients (null until enough calibration data to fit)
  final double? rawBias;
  final List<double>? rawWeights; // length 6: [X1, X2, PI, X1/PI, X2/PI, Ratio_R]

  // Scaler parameters (saved for diagnostics/export)
  final List<double>? scalerMeans;
  final List<double>? scalerStds;

  // Stats
  final int calibrationPointCount;
  final double? mardPercent;
  final double? rmse;

  const PersonalModel({
    required this.id,
    required this.name,
    required this.isDefault,
    required this.createdAt,
    required this.updatedAt,
    this.rawBias,
    this.rawWeights,
    this.scalerMeans,
    this.scalerStds,
    this.calibrationPointCount = 0,
    this.mardPercent,
    this.rmse,
  });

  bool get canPredict => rawBias != null && rawWeights != null;
  bool get needsMoreData =>
      calibrationPointCount < AppConstants.minCalibrationPoints;
  int get pointsNeeded =>
      (AppConstants.minCalibrationPoints - calibrationPointCount)
          .clamp(0, AppConstants.minCalibrationPoints);

  /// Predict glucose in mmol/L from raw sensor features.
  /// Returns null if model cannot predict.
  double? predict(double x1, double x2, double pi, double ratioR) {
    final bias = rawBias;
    final weights = rawWeights;
    if (bias == null || weights == null) return null;

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

  // ─── Built-in default model ────────────────────────────────────────────────

  static PersonalModel get builtInDefault => PersonalModel(
        id: DefaultModel.id,
        name: DefaultModel.name,
        isDefault: true,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        rawBias: DefaultModel.rawBias,
        rawWeights: List<double>.from(DefaultModel.rawWeights),
        calibrationPointCount: 0,
      );

  // ─── Serialization ────────────────────────────────────────────────────────

  PersonalModel copyWith({
    String? name,
    DateTime? updatedAt,
    double? rawBias,
    bool clearCoefficients = false,
    List<double>? rawWeights,
    List<double>? scalerMeans,
    List<double>? scalerStds,
    int? calibrationPointCount,
    double? mardPercent,
    double? rmse,
  }) {
    return PersonalModel(
      id: id,
      name: name ?? this.name,
      isDefault: isDefault,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rawBias: clearCoefficients ? null : (rawBias ?? this.rawBias),
      rawWeights: clearCoefficients ? null : (rawWeights ?? this.rawWeights),
      scalerMeans: clearCoefficients ? null : (scalerMeans ?? this.scalerMeans),
      scalerStds: clearCoefficients ? null : (scalerStds ?? this.scalerStds),
      calibrationPointCount:
          calibrationPointCount ?? this.calibrationPointCount,
      mardPercent: mardPercent ?? this.mardPercent,
      rmse: rmse ?? this.rmse,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'isDefault': isDefault,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'rawBias': rawBias,
        'rawWeights': rawWeights,
        'scalerMeans': scalerMeans,
        'scalerStds': scalerStds,
        'calibrationPointCount': calibrationPointCount,
        'mardPercent': mardPercent,
        'rmse': rmse,
      };

  factory PersonalModel.fromJson(Map<String, dynamic> json) => PersonalModel(
        id: json['id'] as String,
        name: json['name'] as String,
        isDefault: json['isDefault'] as bool? ?? false,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        rawBias: (json['rawBias'] as num?)?.toDouble(),
        rawWeights: (json['rawWeights'] as List<dynamic>?)
            ?.map((e) => (e as num).toDouble())
            .toList(),
        scalerMeans: (json['scalerMeans'] as List<dynamic>?)
            ?.map((e) => (e as num).toDouble())
            .toList(),
        scalerStds: (json['scalerStds'] as List<dynamic>?)
            ?.map((e) => (e as num).toDouble())
            .toList(),
        calibrationPointCount:
            (json['calibrationPointCount'] as num?)?.toInt() ?? 0,
        mardPercent: (json['mardPercent'] as num?)?.toDouble(),
        rmse: (json['rmse'] as num?)?.toDouble(),
      );

  String toDbString() => jsonEncode(toJson());

  factory PersonalModel.fromDbString(String s) =>
      PersonalModel.fromJson(jsonDecode(s) as Map<String, dynamic>);
}
