import 'package:hive_flutter/hive_flutter.dart';
import '../core/constants.dart';
import '../models/measurement.dart';
import '../models/personal_model.dart';
import '../models/calibration_point.dart';

/// Hive-backed persistence layer.
/// All objects stored as JSON strings — no code generation required.
class StorageService {
  Box get _measurements => Hive.box(AppConstants.boxMeasurements);
  Box get _models => Hive.box(AppConstants.boxModels);
  Box get _calibrationPoints => Hive.box(AppConstants.boxCalibrationPoints);

  // ─── Measurements ──────────────────────────────────────────────────────────

  Future<void> saveMeasurement(Measurement m) async {
    await _measurements.put(m.id, m.toDbString());
  }

  Future<List<Measurement>> getAllMeasurements() async {
    final list = _measurements.values
        .map((v) => Measurement.fromDbString(v as String))
        .toList();
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list;
  }

  Future<void> updateMeasurement(Measurement m) async {
    await _measurements.put(m.id, m.toDbString());
  }

  Future<void> deleteMeasurement(String id) async {
    await _measurements.delete(id);
  }

  Future<void> clearAllMeasurements() async {
    await _measurements.clear();
  }

  // ─── Personal models ───────────────────────────────────────────────────────

  Future<void> saveModel(PersonalModel m) async {
    await _models.put(m.id, m.toDbString());
  }

  Future<List<PersonalModel>> getAllModels() async {
    return _models.values
        .map((v) => PersonalModel.fromDbString(v as String))
        .toList();
  }

  Future<void> updateModel(PersonalModel m) async {
    await _models.put(m.id, m.toDbString());
  }

  Future<void> deleteModel(String id) async {
    await _models.delete(id);
  }

  // ─── Calibration points ────────────────────────────────────────────────────

  Future<void> saveCalibrationPoint(CalibrationPoint p) async {
    await _calibrationPoints.put(p.id, p.toDbString());
  }

  Future<List<CalibrationPoint>> getCalibrationPointsForModel(
      String modelId) async {
    final list = _calibrationPoints.values
        .map((v) => CalibrationPoint.fromDbString(v as String))
        .where((p) => p.modelId == modelId)
        .toList();
    list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return list;
  }

  Future<void> deleteCalibrationPoint(String id) async {
    await _calibrationPoints.delete(id);
  }

  Future<void> deleteAllCalibrationPointsForModel(String modelId) async {
    final toDelete = _calibrationPoints.keys.where((k) {
      final v = _calibrationPoints.get(k);
      if (v == null) return false;
      return CalibrationPoint.fromDbString(v as String).modelId == modelId;
    }).toList();
    await _calibrationPoints.deleteAll(toDelete);
  }
}
