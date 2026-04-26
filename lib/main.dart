import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/database_provider.dart';
import 'providers/bluetooth_provider.dart';
import 'screens/main_screen.dart';
import 'services/background_dose_scheduler.dart';
import 'services/medicine_automation_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await BackgroundDoseScheduler.instance.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DatabaseProvider()),
        ChangeNotifierProvider(create: (_) => BluetoothProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MediDispense',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.teal,
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.grey[100],
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      home: const _AutomationBootstrap(),
    );
  }
}

class _AutomationBootstrap extends StatefulWidget {
  const _AutomationBootstrap();

  @override
  State<_AutomationBootstrap> createState() => _AutomationBootstrapState();
}

class _AutomationBootstrapState extends State<_AutomationBootstrap> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final dbProvider = context.read<DatabaseProvider>();
      MedicineAutomationService.instance.start(dbProvider);
      BackgroundDoseScheduler.instance.scheduleAllPendingDoseAlarms();
    });
  }

  @override
  void dispose() {
    MedicineAutomationService.instance.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const MainScreen();
  }
}
