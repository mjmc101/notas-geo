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
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      return false;
    }

    // If only "while in use", try to upgrade to "always" for background use.
    // On Android 11+, this redirects to app settings.
    if (perm == LocationPermission.whileInUse) {
      final bg = await Permission.locationAlways.status;
      if (bg.isDenied) await Permission.locationAlways.request();
    }

    return true;
  }

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

    // distanceFilter:0 so updates arrive on time alone, not distance.
    // Accuracy.medium (balanced power) is sufficient for geofencing;
    // high accuracy is reserved for the one-shot checkNow() calls.
    final settings = AndroidSettings(
      accuracy: LocationAccuracy.medium,
      distanceFilter: 0,
      intervalDuration: const Duration(seconds: 15),
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationTitle: 'Notas & Avisos',
        notificationText: 'A monitorizar a sua localização em segundo plano',
        notificationChannelName: 'Location monitoring',
        enableWakeLock: true,
      ),
    );

    _subscription = Geolocator.getPositionStream(locationSettings: settings)
        .listen(_onPosition, onError: (_) => _isRunning = false);

    // Immediate high-accuracy check without waiting for first stream event.
    unawaited(checkNow());
  }

  void stopMonitoring() {
    _subscription?.cancel();
    _subscription = null;
    _isRunning = false;
  }

  void resetTrigger(String noteId) {
    _triggered.remove(noteId);
  }

  /// Gets the current position once and runs the geofence check immediately.
  /// Call this after saving a note or whenever an instant check is needed.
  Future<void> checkNow() async {
    if (!_isRunning) return;
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      _onPosition(pos);
    } catch (_) {
      // Permission denied, GPS unavailable, or timeout — skip silently.
    }
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
      } else if (dist > loc.radiusMeters * 1.5) {
        // Reset trigger when user moves clearly outside the zone so they
        // get a notification again on re-entry.
        _triggered.remove(note.id);
      }
    }
  }
}
