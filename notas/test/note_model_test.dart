import 'package:flutter_test/flutter_test.dart';
import 'package:notas/models/note.dart';

void main() {
  group('LocationAlert.hasTimeWindow', () {
    test('true when both minutes set', () {
      final loc = LocationAlert(
        latitude: 0,
        longitude: 0,
        radiusMeters: 100,
        timeWindowStartMinutes: 540,
        timeWindowEndMinutes: 1080,
      );
      expect(loc.hasTimeWindow, isTrue);
    });

    test('false when only start is set', () {
      final loc = LocationAlert(
        latitude: 0,
        longitude: 0,
        radiusMeters: 100,
        timeWindowStartMinutes: 540,
      );
      expect(loc.hasTimeWindow, isFalse);
    });

    test('false when nothing set', () {
      final loc =
          LocationAlert(latitude: 0, longitude: 0, radiusMeters: 100);
      expect(loc.hasTimeWindow, isFalse);
    });
  });

  group('LocationAlert.hasDateRestriction', () {
    test('true when dateRangeStart is set', () {
      final loc = LocationAlert(
        latitude: 0,
        longitude: 0,
        radiusMeters: 100,
        dateRangeStart: DateTime(2025, 6, 15),
      );
      expect(loc.hasDateRestriction, isTrue);
    });

    test('false when dateRangeStart is null', () {
      final loc =
          LocationAlert(latitude: 0, longitude: 0, radiusMeters: 100);
      expect(loc.hasDateRestriction, isFalse);
    });
  });

  group('LocationAlert.hasRestriction', () {
    test('true with time window only', () {
      final loc = LocationAlert(
        latitude: 0,
        longitude: 0,
        radiusMeters: 100,
        timeWindowStartMinutes: 540,
        timeWindowEndMinutes: 1080,
      );
      expect(loc.hasRestriction, isTrue);
    });

    test('true with date only', () {
      final loc = LocationAlert(
        latitude: 0,
        longitude: 0,
        radiusMeters: 100,
        dateRangeStart: DateTime(2025, 6, 15),
      );
      expect(loc.hasRestriction, isTrue);
    });

    test('false with nothing', () {
      final loc =
          LocationAlert(latitude: 0, longitude: 0, radiusMeters: 100);
      expect(loc.hasRestriction, isFalse);
    });
  });

  group('TimeAlert', () {
    test('non-recurring', () {
      final dt = DateTime(2025, 12, 25, 9, 0);
      final alert = TimeAlert(dateTime: dt);
      expect(alert.isRecurring, isFalse);
      expect(alert.recurringType, isNull);
      expect(alert.dateTime, equals(dt));
    });

    test('daily recurring', () {
      final alert = TimeAlert(
        dateTime: DateTime(2025, 1, 1, 8, 30),
        isRecurring: true,
        recurringType: 'daily',
      );
      expect(alert.isRecurring, isTrue);
      expect(alert.recurringType, 'daily');
    });
  });

  group('Note defaults', () {
    test('isDone defaults to false', () {
      final note = Note(title: 'Test', description: '');
      expect(note.isDone, isFalse);
    });

    test('id is auto-generated when not provided', () {
      final n1 = Note(title: 'A', description: '');
      final n2 = Note(title: 'B', description: '');
      expect(n1.id, isNotEmpty);
      expect(n1.id, isNot(equals(n2.id)));
    });
  });
}
