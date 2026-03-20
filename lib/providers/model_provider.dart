import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../core/constants.dart';
import '../models/personal_model.dart';
import '../models/calibration_point.dart';
import '../services/regression_service.dart';
import '../services/storage_service.dart';

class ModelProvider extends ChangeNotifier {
  final StorageService _storage = StorageService();
  final _uuid = const Uuid();

  List<PersonalModel> _personalModels = [];
  String _activeModelId = PersonalModel.builtInDefault.id;

  List<PersonalModel> get models => _personalModels;

  /// All models including the built-in default (always first).
  List<PersonalModel> get allModels =>
      [PersonalModel.builtInDefault, ..._personalModels];

  /// Currently active model (falls back to built-in default).
  PersonalModel get activeModel {
    if (_activeModelId == PersonalModel.builtInDefault.id) {
      return PersonalModel.builtInDefault;
    }
    return _personalModels.firstWhere(
      (m) => m.id == _activeModelId,
      orElse: () => PersonalModel.builtInDefault,
    );
  }

  bool get hasReadyModel => activeModel.canPredict;

  ModelProvider() {
    _init();
  }

  Future<void> _init() async {
    _personalModels = await _storage.getAllModels();
    notifyListeners();
  }

  void setActiveModel(String id) {
    _activeModelId = id;
    notifyListeners();
  }

  Future<PersonalModel> createModel(String name) async {
    final now = DateTime.now();
    final model = PersonalModel(
      id: _uuid.v4(),
      name: name,
      isDefault: false,
      createdAt: now,
      updatedAt: now,
    );
    await _storage.saveModel(model);
    _personalModels.insert(0, model);
    notifyListeners();
    return model;
  }

  Future<void> deleteModel(String modelId) async {
    if (modelId == PersonalModel.builtInDefault.id) return;
    await _storage.deleteModel(modelId);
    await _storage.deleteAllCalibrationPointsForModel(modelId);
    _personalModels.removeWhere((m) => m.id == modelId);
    if (_activeModelId == modelId) {
      _activeModelId = PersonalModel.builtInDefault.id;
    }
    notifyListeners();
  }

  Future<void> renameModel(String modelId, String newName) async {
    final idx = _personalModels.indexWhere((m) => m.id == modelId);
    if (idx < 0) return;
    final updated = _personalModels[idx].copyWith(
      name: newName,
      updatedAt: DateTime.now(),
    );
    _personalModels[idx] = updated;
    await _storage.updateModel(updated);
    notifyListeners();
  }

  /// Add a calibration point to the active personal model and re-fit if ready.
  Future<void> addCalibrationPoint({
    required String measurementId,
    required double x1,
    required double x2,
    required double pi,
    required double ratioR,
    required double referenceGlucose,
  }) async {
    // Only add to personal (non-default) models
    final modelId = _activeModelId == PersonalModel.builtInDefault.id
        ? (_personalModels.isEmpty ? null : _personalModels.first.id)
        : _activeModelId;
    if (modelId == null) return;

    final idx = _personalModels.indexWhere((m) => m.id == modelId);
    if (idx < 0) return;

    final point = CalibrationPoint(
      id: _uuid.v4(),
      modelId: modelId,
      measurementId: measurementId,
      timestamp: DateTime.now(),
      x1: x1,
      x2: x2,
      pi: pi,
      ratioR: ratioR,
      referenceGlucose: referenceGlucose,
    );
    await _storage.saveCalibrationPoint(point);

    final currentCount = _personalModels[idx].calibrationPointCount + 1;
    _personalModels[idx] = _personalModels[idx].copyWith(
      calibrationPointCount: currentCount,
      updatedAt: DateTime.now(),
    );
    await _storage.updateModel(_personalModels[idx]);
    notifyListeners();

    if (currentCount >= AppConstants.minCalibrationPoints) {
      await _refitModel(modelId);
    }
  }

  Future<void> deleteCalibrationPoint(
      String modelId, String pointId) async {
    await _storage.deleteCalibrationPoint(pointId);
    final idx = _personalModels.indexWhere((m) => m.id == modelId);
    if (idx < 0) return;

    final points = await _storage.getCalibrationPointsForModel(modelId);
    _personalModels[idx] = _personalModels[idx].copyWith(
      calibrationPointCount: points.length,
      updatedAt: DateTime.now(),
    );

    if (points.length >= AppConstants.minCalibrationPoints) {
      await _refitModel(modelId);
    } else {
      // Clear coefficients — not enough data
      _personalModels[idx] =
          _personalModels[idx].copyWith(clearCoefficients: true);
      await _storage.updateModel(_personalModels[idx]);
      notifyListeners();
    }
  }

  Future<void> refitModelManually(String modelId) => _refitModel(modelId);

  Future<void> _refitModel(String modelId) async {
    final idx = _personalModels.indexWhere((m) => m.id == modelId);
    if (idx < 0) return;

    final points = await _storage.getCalibrationPointsForModel(modelId);
    if (points.length < AppConstants.minCalibrationPoints) return;

    final result = RegressionService.fit(points);
    if (result == null) return;

    _personalModels[idx] = _personalModels[idx].copyWith(
      rawBias: result.rawBias,
      rawWeights: result.rawWeights,
      scalerMeans: result.scalerMeans,
      scalerStds: result.scalerStds,
      mardPercent: result.mard,
      rmse: result.rmse,
      calibrationPointCount: points.length,
      updatedAt: DateTime.now(),
    );
    await _storage.updateModel(_personalModels[idx]);
    notifyListeners();
  }

  // ─── Calibration data access ───────────────────────────────────────────────

  Future<List<CalibrationPoint>> getCalibrationPoints(String modelId) async {
    return _storage.getCalibrationPointsForModel(modelId);
  }

  // ─── Export / Import ───────────────────────────────────────────────────────

  Future<String> exportModelJson(String modelId) async {
    final model = allModels.firstWhere((m) => m.id == modelId);
    final points = await _storage.getCalibrationPointsForModel(modelId);
    final data = {
      'model': model.toJson(),
      'calibrationPoints': points.map((p) => p.toJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  Future<PersonalModel> importModelJson(String jsonStr) async {
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;
    final now = DateTime.now();
    final model = PersonalModel.fromJson(data['model'] as Map<String, dynamic>)
        .copyWith(
      name: '${(data['model'] as Map<String, dynamic>)['name']} (import)',
      updatedAt: now,
    );
    // Assign new ID to avoid collision
    final newId = _uuid.v4();
    final newModel = PersonalModel(
      id: newId,
      name: model.name,
      isDefault: false,
      createdAt: model.createdAt,
      updatedAt: now,
      rawBias: model.rawBias,
      rawWeights: model.rawWeights,
      scalerMeans: model.scalerMeans,
      scalerStds: model.scalerStds,
      calibrationPointCount: model.calibrationPointCount,
      mardPercent: model.mardPercent,
      rmse: model.rmse,
    );
    await _storage.saveModel(newModel);

    // Import calibration points
    final points = (data['calibrationPoints'] as List<dynamic>? ?? [])
        .map((e) {
      final p = CalibrationPoint.fromJson(e as Map<String, dynamic>);
      return CalibrationPoint(
        id: _uuid.v4(),
        modelId: newId,
        measurementId: p.measurementId,
        timestamp: p.timestamp,
        x1: p.x1,
        x2: p.x2,
        pi: p.pi,
        ratioR: p.ratioR,
        referenceGlucose: p.referenceGlucose,
      );
    }).toList();
    for (final pt in points) {
      await _storage.saveCalibrationPoint(pt);
    }

    _personalModels.insert(0, newModel);
    notifyListeners();
    return newModel;
  }
}
