// Pure, side-effect-free geofence logic extracted from LocationService so
// it can be unit-tested without any platform plugins.
import '../models/note.dart';
import 'location_config.dart';
import 'restriction_checker.dart';

class GeofenceChecker {
  GeofenceChecker._();

  /// Returns true when a location notification should fire.
  ///
  /// All three conditions must hold:
  ///   1. The user is inside the geofence (dist ≤ radius).
  ///   2. The notification has not already fired since the last entry.
  ///   3. Any time/date restriction on the alert is currently satisfied.
  static bool shouldFire({
    required double distanceMeters,
    required double radiusMeters,
    required bool alreadyTriggered,
    required LocationAlert loc,
    required DateTime now,
  }) {
    if (distanceMeters > radiusMeters) return false;
    if (alreadyTriggered) return false;
    return RestrictionChecker.isWithinRestriction(loc, now);
  }

  /// Returns true when the trigger should be reset so the user can receive
  /// the notification again on next entry.
  ///
  /// Uses a multiplier > 1 to create hysteresis: the user must move clearly
  /// outside the zone before the trigger resets, preventing repeated
  /// notifications when standing on the geofence boundary.
  static bool shouldReset({
    required double distanceMeters,
    required double radiusMeters,
  }) {
    return distanceMeters > radiusMeters * LocationConfig.triggerResetMultiplier;
  }
}
