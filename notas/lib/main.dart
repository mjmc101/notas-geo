import 'package:flutter/material.dart';
import 'services/hive_service.dart';
import 'services/notification_service.dart';
import 'services/location_service.dart';
import 'screens/home_screen.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveService.init();
  await NotificationService.init();
  runApp(const NotasApp());
}

class NotasApp extends StatefulWidget {
  const NotasApp({super.key});

  @override
  State<NotasApp> createState() => _NotasAppState();
}

class _NotasAppState extends State<NotasApp> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // Notification permissions (POST_NOTIFICATIONS on Android 13+)
    await NotificationService.requestPermissions();

    // Exact alarm permission (SCHEDULE_EXACT_ALARM on Android 12+)
    await NotificationService.requestExactAlarmPermission();

    // Battery optimisation exemption – keeps the location foreground service
    // alive when the screen turns off
    await LocationService.instance.requestBatteryOptimizationExemption();

    final notes = HiveService.getAllNotes();

    final hasLocNotes = notes.any((n) => !n.isDone && n.locationAlert != null);
    if (hasLocNotes) {
      await LocationService.instance.startMonitoring();
      // checkNow() is already called inside startMonitoring()
    }

    for (final note in notes) {
      if (!note.isDone && note.timeAlert != null) {
        await NotificationService.scheduleTimeAlert(note);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Notas & Avisos',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const HomeScreen(),
    );
  }
}
