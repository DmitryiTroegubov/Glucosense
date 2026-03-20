import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';

class SettingsProvider extends ChangeNotifier {
  // Device
  String deviceName = AppConstants.defaultDeviceName;

  // Quality thresholds
  double minCorrelation = AppConstants.defaultMinCorrelation;
  double minPI = AppConstants.defaultMinPI;
  double maxDrift = AppConstants.defaultMaxDrift;
  int minBeats = AppConstants.defaultMinBeats;
  int minSamples = AppConstants.defaultMinSamples;

  // Display
  bool useMgdl = false;
  bool isDarkTheme = false;

  SettingsProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    deviceName =
        prefs.getString('deviceName') ?? AppConstants.defaultDeviceName;
    minCorrelation = prefs.getDouble('minCorrelation') ??
        AppConstants.defaultMinCorrelation;
    minPI = prefs.getDouble('minPI') ?? AppConstants.defaultMinPI;
    maxDrift = prefs.getDouble('maxDrift') ?? AppConstants.defaultMaxDrift;
    minBeats = prefs.getInt('minBeats') ?? AppConstants.defaultMinBeats;
    minSamples = prefs.getInt('minSamples') ?? AppConstants.defaultMinSamples;
    useMgdl = prefs.getBool('useMgdl') ?? false;
    isDarkTheme = prefs.getBool('isDarkTheme') ?? false;
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('deviceName', deviceName);
    await prefs.setDouble('minCorrelation', minCorrelation);
    await prefs.setDouble('minPI', minPI);
    await prefs.setDouble('maxDrift', maxDrift);
    await prefs.setInt('minBeats', minBeats);
    await prefs.setInt('minSamples', minSamples);
    await prefs.setBool('useMgdl', useMgdl);
    await prefs.setBool('isDarkTheme', isDarkTheme);
  }

  void setDeviceName(String v) { deviceName = v; _save(); notifyListeners(); }
  void setMinCorrelation(double v) { minCorrelation = v; _save(); notifyListeners(); }
  void setMinPI(double v) { minPI = v; _save(); notifyListeners(); }
  void setMaxDrift(double v) { maxDrift = v; _save(); notifyListeners(); }
  void setMinBeats(int v) { minBeats = v; _save(); notifyListeners(); }
  void setMinSamples(int v) { minSamples = v; _save(); notifyListeners(); }
  void setUseMgdl(bool v) { useMgdl = v; _save(); notifyListeners(); }
  void setDarkTheme(bool v) { isDarkTheme = v; _save(); notifyListeners(); }
}
