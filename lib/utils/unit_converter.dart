import '../core/constants.dart';

class UnitConverter {
  static double mmolToMgdl(double mmol) => mmol * AppConstants.mmolToMgdl;
  static double mgdlToMmol(double mgdl) => mgdl / AppConstants.mmolToMgdl;

  static String formatGlucose(double mmol, {bool useMgdl = false, int decimals = 1}) {
    if (useMgdl) {
      return mmolToMgdl(mmol).toStringAsFixed(0);
    }
    return mmol.toStringAsFixed(decimals);
  }

  static String unitLabel({bool useMgdl = false}) => useMgdl ? 'mg/dL' : 'mmol/L';

  /// Convert a value entered by user in the current unit to mmol/L for storage.
  static double toMmol(double value, {bool inputIsMgdl = false}) {
    if (inputIsMgdl) return mgdlToMmol(value);
    return value;
  }

  /// Return the display value in the chosen unit (mmol/L or mg/dL).
  static double display(double mmol, bool useMgdl) {
    return useMgdl ? mmolToMgdl(mmol) : mmol;
  }
}
