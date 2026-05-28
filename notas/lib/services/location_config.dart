// Battery-relevant constants for LocationService.
// Pure Dart (no platform imports) so they can be unit-tested and audited
// independently of the plugin infrastructure.
//
// LocationAccuracy enum levels (geolocator):
//   0 lowest  ~3000 m   1 low     ~1000 m   2 medium ~100 m
//   3 high      ~10 m   4 best      ~1 m    5 bestForNavigation
class LocationConfig {
  LocationConfig._();

  // --- stream (continuous background monitoring) ---

  // Balanced-power tier: uses cell/Wi-Fi, avoids continuous GPS chip.
  // For geofences ≥ 50 m this is sufficient; high accuracy is reserved
  // for the one-shot checkNow() call.
  static const int streamAccuracyLevel = 2; // LocationAccuracy.medium

  // How often the OS delivers a new position to the stream.
  // 15 s: responsive enough for geofencing, rare enough to not drain GPS.
  static const Duration streamInterval = Duration(seconds: 15);

  // --- checkNow (one-shot on app start / after saving a note) ---

  // High accuracy for the brief initial fix; GPS is active only for
  // the duration of this single call, not continuously.
  static const int checkNowAccuracyLevel = 3; // LocationAccuracy.high

  // Give GPS up to this long to get a fix before giving up.
  static const Duration checkNowTimeout = Duration(seconds: 10);

  // --- geofence hysteresis ---

  // User must move this many × radiusMeters away before the trigger resets.
  // > 1.0 prevents repeated notifications when sitting on the zone boundary.
  static const double triggerResetMultiplier = 1.5;

  // --- acceptable-range bounds used by battery tests ---
  static const Duration minStreamInterval = Duration(seconds: 10);
  static const Duration maxStreamInterval = Duration(seconds: 60);
  static const Duration minCheckNowTimeout = Duration(seconds: 5);
  static const Duration maxCheckNowTimeout = Duration(seconds: 30);
  // "balanced power or lower" — anything above medium (>2) hits GPS chip
  static const int maxBatteryFriendlyAccuracyLevel = 2;
}
