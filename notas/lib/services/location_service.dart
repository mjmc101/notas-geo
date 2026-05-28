import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'hive_service.dart';
import 'notification_service.dart';
import 'restriction_checker.dart';

class LocationService {
  static LocationService? _instance;
  static LocationService get instance => _instance ??= LocationService._();
  LocationService._();

  StreamSubscription<Position>? _subscription;
  final Map<String, bool> _triggered = {};
  bool _isRunning = false;

  bool get isRunning => _isRunning;

  Future<bool> requestPermissions() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    return perm != LocationPermission.denied &&
        perm != LocationPermission.deniedForever;
  }

  /// Requests the system to exempt this app from battery optimisation so the
  /// foreground location service is not killed when the screen is off.
  Future<void> requestBatteryOptimizationExemption() async {
    final status = await Permission.ignoreBatteryOptimizations.status;
    if (status.isDenied) {
      await Permission.ignoreBatteryOptimizations.request();
    }
  }

  Future<void> startMonitoring() async {
    if (_isRunning) return;
    if (!await requestPermissions()) return;

    _isRunning = true;
    final settings = AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 15,
      intervalDuration: Duration(seconds: 20),
      foregroundNotificationConfig: ForegroundNotificationConfig(
        notificationText: 'A monitorizar a sua localização em segundo plano',
        notificationTitle: 'Notas & Avisos',
        enableWakeLock: true,
      ),
    );

    _subscription = Geolocator.getPositionStream(locationSettings: settings)
        .listen(_onPosition, onError: (_) => _isRunning = false);
  }

  void stopMonitoring() {
    _subscription?.cancel();
    _subscription = null;
    _isRunning = false;
  }

  void resetTrigger(String noteId) {
    _triggered.remove(noteId);
  }

  void _onPosition(Position pos) {
    final notes = HiveService.getAllNotes();
    final now = DateTime.now();

    for (final note in notes) {
      if (note.isDone) continue;
      final loc = note.locationAlert;
      if (loc == null) continue;

      final dist = Geolocator.distanceBetween(
        pos.latitude, pos.longitude, loc.latitude, loc.longitude,
      );

      if (dist <= loc.radiusMeters) {
        if (_triggered[note.id] == true) continue;

        if (!RestrictionChecker.isWithinRestriction(loc, now)) continue;

        _triggered[note.id] = true;
        NotificationService.sendLocationAlert(note);
      } else if (dist > loc.radiusMeters * 2.5) {
        _triggered.remove(note.id);
      }
    }
  }
}
