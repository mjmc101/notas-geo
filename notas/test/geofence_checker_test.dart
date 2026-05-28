// Unit tests for GeofenceChecker.
//
// GeofenceChecker is pure Dart with no platform dependencies, so these run
// without any Flutter binding or mock setup.
import 'package:flutter_test/flutter_test.dart';
import 'package:notas/services/geofence_checker.dart';
import 'package:notas/models/note.dart';

void main() {
  // No restrictions — fires whenever inside the geofence.
  LocationAlert bare({double radius = 100}) =>
      LocationAlert(latitude: 0, longitude: 0, radiusMeters: radius);

  // Time window 09:00–18:00 (minutes 540–1080), no date restriction.
  LocationAlert withWindow({double radius = 100}) => LocationAlert(
        latitude: 0,
        longitude: 0,
        radiusMeters: radius,
        timeWindowStartMinutes: 540,
        timeWindowEndMinutes: 1080,
      );

  group('GeofenceChecker.shouldFire', () {
    test('inside radius, not triggered, no restriction → fires', () {
      expect(
        GeofenceChecker.shouldFire(
          distanceMeters: 50,
          radiusMeters: 100,
          alreadyTriggered: false,
          loc: bare(),
          now: DateTime(2025, 6, 1, 12),
        ),
        isTrue,
      );
    });

    test('outside radius → does not fire', () {
      expect(
        GeofenceChecker.shouldFire(
          distanceMeters: 101,
          radiusMeters: 100,
          alreadyTriggered: false,
          loc: bare(),
          now: DateTime(2025, 6, 1, 12),
        ),
        isFalse,
      );
    });

    test('inside radius but already triggered → does not fire', () {
      expect(
        GeofenceChecker.shouldFire(
          distanceMeters: 50,
          radiusMeters: 100,
          alreadyTriggered: true,
          loc: bare(),
          now: DateTime(2025, 6, 1, 12),
        ),
        isFalse,
      );
    });

    test('exactly on boundary (dist == radius) → fires (strict > check)', () {
      expect(
        GeofenceChecker.shouldFire(
          distanceMeters: 100,
          radiusMeters: 100,
          alreadyTriggered: false,
          loc: bare(),
          now: DateTime(2025, 6, 1, 12),
        ),
        isTrue,
      );
    });

    test('inside radius but before time window → does not fire', () {
      // Window: 09:00–18:00; now is 08:59 → outside window.
      expect(
        GeofenceChecker.shouldFire(
          distanceMeters: 50,
          radiusMeters: 100,
          alreadyTriggered: false,
          loc: withWindow(),
          now: DateTime(2025, 6, 1, 8, 59),
        ),
        isFalse,
      );
    });

    test('inside radius and inside time window → fires', () {
      // Window: 09:00–18:00; now is 12:00 → inside window.
      expect(
        GeofenceChecker.shouldFire(
          distanceMeters: 50,
          radiusMeters: 100,
          alreadyTriggered: false,
          loc: withWindow(),
          now: DateTime(2025, 6, 1, 12),
        ),
        isTrue,
      );
    });

    test('inside radius and after time window → does not fire', () {
      // Window: 09:00–18:00; now is 18:01.
      expect(
        GeofenceChecker.shouldFire(
          distanceMeters: 50,
          radiusMeters: 100,
          alreadyTriggered: false,
          loc: withWindow(),
          now: DateTime(2025, 6, 1, 18, 1),
        ),
        isFalse,
      );
    });
  });

  group('GeofenceChecker.shouldReset', () {
    // triggerResetMultiplier = 1.5 → threshold = radius * 1.5.
    // Uses strict >, so dist == threshold does NOT reset.

    test('well beyond threshold → resets', () {
      // dist=200 > 100*1.5=150
      expect(
        GeofenceChecker.shouldReset(distanceMeters: 200, radiusMeters: 100),
        isTrue,
      );
    });

    test('exactly at threshold → does NOT reset (strict >)', () {
      // dist=150 is NOT > 150
      expect(
        GeofenceChecker.shouldReset(distanceMeters: 150, radiusMeters: 100),
        isFalse,
      );
    });

    test('just beyond threshold → resets', () {
      // dist=150.1 > 100*1.5=150
      expect(
        GeofenceChecker.shouldReset(distanceMeters: 150.1, radiusMeters: 100),
        isTrue,
      );
    });

    test('inside radius → does not reset', () {
      expect(
        GeofenceChecker.shouldReset(distanceMeters: 50, radiusMeters: 100),
        isFalse,
      );
    });
  });
}
