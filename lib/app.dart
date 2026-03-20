import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/app_state.dart';
import 'providers/model_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/history_screen.dart';
import 'screens/measurement_screen.dart';
import 'screens/models_screen.dart';
import 'screens/serial_monitor_screen.dart';
import 'screens/settings_screen.dart';
import 'theme/app_theme.dart';

class GlucoSenseApp extends StatelessWidget {
  const GlucoSenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return MaterialApp(
      title: 'GlucoSense',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: settings.isDarkTheme ? ThemeMode.dark : ThemeMode.light,
      home: const _AppShell(),
    );
  }
}

class _AppShell extends StatefulWidget {
  const _AppShell();

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  int _tab = 0;

  static const _screens = [
    MeasurementScreen(),
    HistoryScreen(),
    ModelsScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Wire settings → AppStateProvider so quality thresholds are accessible
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = context.read<AppStateProvider>();
      final settings = context.read<SettingsProvider>();
      final modelProvider = context.read<ModelProvider>();
      appState.wireSettings(settings);

      // Wire active model to AppStateProvider whenever model changes
      appState.setActiveModel(modelProvider.activeModel.id);
    });
  }

  static String _tabTitle(int tab) {
    switch (tab) {
      case 1: return 'History';
      case 2: return 'Models';
      case 3: return 'Settings';
      default: return 'GlucoSense';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: _screens[_tab]),
      appBar: _tab == 0
          ? null
          : AppBar(
              title: Text(_tabTitle(_tab)),
              actions: [
                IconButton(
                  icon: const Icon(Icons.terminal_outlined),
                  tooltip: 'Serial Monitor',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SerialMonitorScreen(),
                    ),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.monitor_heart_outlined),
            selectedIcon: Icon(Icons.monitor_heart),
            label: 'Measure',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Models',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
