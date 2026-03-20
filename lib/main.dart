import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'core/constants.dart';
import 'providers/app_state.dart';
import 'providers/model_provider.dart';
import 'providers/settings_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  await Hive.openBox(AppConstants.boxMeasurements);
  await Hive.openBox(AppConstants.boxModels);
  await Hive.openBox(AppConstants.boxCalibrationPoints);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => ModelProvider()),
        ChangeNotifierProvider(create: (_) => AppStateProvider()),
      ],
      child: const GlucoSenseApp(),
    ),
  );
}
