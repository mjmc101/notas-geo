// Battery-efficiency guard tests.
//
// These tests do NOT measure actual power draw — for that, use the ADB
// script at tools/battery_test.ps1.
//
// What they DO guarantee: the configuration constants in LocationConfig
// stay within ranges that are known to be battery-friendly.  If someone
// accidentally changes streamInterval to 1 s or bumps streamAccuracyLevel
// to "best", these tests will fail immediately in CI before it reaches a
// device.
import 'package:flutter_test/flutter_test.dart';
import 'package:notas/services/location_config.dart';

void main() {
  group('LocationConfig — stream interval', () {
    test('is at least ${LocationConfig.minStreamInterval.inSeconds} seconds '
        '(below this, GPS wakes up too often)', () {
      expect(
        LocationConfig.streamInterval.inSeconds,
        greaterThanOrEqualTo(LocationConfig.minStreamInterval.inSeconds),
      );
    });

    test('is at most ${LocationConfig.maxStreamInterval.inSeconds} seconds '
        '(above this, geofence entry can be missed)', () {
      expect(
        LocationConfig.streamInterval.inSeconds,
        lessThanOrEqualTo(LocationConfig.maxStreamInterval.inSeconds),
      );
    });
  });

  group('LocationConfig — stream accuracy', () {
    test('is medium or lower (level ≤ ${LocationConfig.maxBatteryFriendlyAccuracyLevel})'
        ' — avoids continuous GPS chip activation', () {
      // Levels: 0 lowest, 1 low, 2 medium, 3 high, 4 best, 5 bestForNavigation.
      // Anything above medium switches the GPS chip on continuously.
      expect(
        LocationConfig.streamAccuracyLevel,
        lessThanOrEqualTo(LocationConfig.maxBatteryFriendlyAccuracyLevel),
      );
    });

    test('checkNow accuracy is higher than stream accuracy '
        '(brief one-shot fix should be more precise than the stream)', () {
      expect(
        LocationConfig.checkNowAccuracyLevel,
        greaterThan(LocationConfig.streamAccuracyLevel),
      );
    });
  });

  group('LocationConfig — checkNow timeout', () {
    test('is at least ${LocationConfig.minCheckNowTimeout.inSeconds} seconds '
        '(below this, GPS rarely gets a fix)', () {
      expect(
        LocationConfig.checkNowTimeout.inSeconds,
        greaterThanOrEqualTo(LocationConfig.minCheckNowTimeout.inSeconds),
      );
    });

    test('is at most ${LocationConfig.maxCheckNowTimeout.inSeconds} seconds '
        '(longer keeps GPS on too long for a one-shot call)', () {
      expect(
        LocationConfig.checkNowTimeout.inSeconds,
        lessThanOrEqualTo(LocationConfig.maxCheckNowTimeout.inSeconds),
      );
    });
  });

  group('LocationConfig — hysteresis multiplier', () {
    test('trigger reset multiplier is greater than 1.0 '
        '(prevents repeated notifications on zone boundary)', () {
      expect(LocationConfig.triggerResetMultiplier, greaterThan(1.0));
    });

    test('trigger reset multiplier is at most 3.0 '
        '(too large means no re-notification after short exit)', () {
      expect(LocationConfig.triggerResetMultiplier, lessThanOrEqualTo(3.0));
    });
  });

  group('LocationConfig — GPS wake-up rate estimate', () {
    test('stream wakes GPS at most 6 times per minute with current interval', () {
      // Upper bound: 60 / interval ≤ 6 activations/minute
      const maxActivationsPerMinute = 6;
      final activationsPerMinute =
          60 / LocationConfig.streamInterval.inSeconds;
      expect(activationsPerMinute, lessThanOrEqualTo(maxActivationsPerMinute));
    });
  });
}
