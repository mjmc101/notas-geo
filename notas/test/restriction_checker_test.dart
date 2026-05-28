import 'package:flutter_test/flutter_test.dart';
import 'package:notas/models/note.dart';
import 'package:notas/services/restriction_checker.dart';

LocationAlert _loc({
  int? startMin,
  int? endMin,
  DateTime? dateStart,
  DateTime? dateEnd,
}) =>
    LocationAlert(
      latitude: 0,
      longitude: 0,
      radiusMeters: 100,
      timeWindowStartMinutes: startMin,
      timeWindowEndMinutes: endMin,
      dateRangeStart: dateStart,
      dateRangeEnd: dateEnd,
    );

DateTime _dt(int h, int m, {int year = 2025, int month = 6, int day = 15}) =>
    DateTime(year, month, day, h, m);

void main() {
  group('RestrictionChecker – no restriction', () {
    test('always true when no restriction set', () {
      final loc = _loc();
      expect(RestrictionChecker.isWithinRestriction(loc, _dt(0, 0)), isTrue);
      expect(RestrictionChecker.isWithinRestriction(loc, _dt(23, 59)), isTrue);
    });
  });

  group('RestrictionChecker – time window only', () {
    // 09:00–18:00
    final loc = _loc(startMin: 540, endMin: 1080);

    test('inside window', () {
      expect(
          RestrictionChecker.isWithinRestriction(loc, _dt(9, 0)), isTrue);
      expect(
          RestrictionChecker.isWithinRestriction(loc, _dt(12, 30)), isTrue);
      expect(
          RestrictionChecker.isWithinRestriction(loc, _dt(18, 0)), isTrue);
    });

    test('outside window', () {
      expect(
          RestrictionChecker.isWithinRestriction(loc, _dt(8, 59)), isFalse);
      expect(
          RestrictionChecker.isWithinRestriction(loc, _dt(18, 1)), isFalse);
      expect(
          RestrictionChecker.isWithinRestriction(loc, _dt(0, 0)), isFalse);
    });
  });

  group('RestrictionChecker – overnight time window', () {
    // 22:00–06:00
    final loc = _loc(startMin: 22 * 60, endMin: 6 * 60);

    test('inside overnight window', () {
      expect(
          RestrictionChecker.isWithinRestriction(loc, _dt(22, 0)), isTrue);
      expect(
          RestrictionChecker.isWithinRestriction(loc, _dt(23, 59)), isTrue);
      expect(
          RestrictionChecker.isWithinRestriction(loc, _dt(0, 0)), isTrue);
      expect(
          RestrictionChecker.isWithinRestriction(loc, _dt(6, 0)), isTrue);
    });

    test('outside overnight window', () {
      expect(
          RestrictionChecker.isWithinRestriction(loc, _dt(6, 1)), isFalse);
      expect(
          RestrictionChecker.isWithinRestriction(loc, _dt(21, 59)), isFalse);
      expect(
          RestrictionChecker.isWithinRestriction(loc, _dt(12, 0)), isFalse);
    });
  });

  group('RestrictionChecker – single date', () {
    final targetDate = DateTime(2025, 6, 15);
    final loc = _loc(dateStart: targetDate);

    test('on the correct date', () {
      expect(
          RestrictionChecker.isWithinRestriction(loc, _dt(0, 0)), isTrue);
      expect(
          RestrictionChecker.isWithinRestriction(loc, _dt(23, 59)), isTrue);
    });

    test('before the date', () {
      expect(
          RestrictionChecker.isWithinRestriction(
              loc, DateTime(2025, 6, 14, 23, 59)),
          isFalse);
    });

    test('after the date', () {
      expect(
          RestrictionChecker.isWithinRestriction(
              loc, DateTime(2025, 6, 16, 0, 0)),
          isFalse);
    });
  });

  group('RestrictionChecker – date range', () {
    final loc = _loc(
      dateStart: DateTime(2025, 6, 10),
      dateEnd: DateTime(2025, 6, 20),
    );

    test('inside date range', () {
      expect(
          RestrictionChecker.isWithinRestriction(
              loc, DateTime(2025, 6, 10, 12, 0)),
          isTrue);
      expect(
          RestrictionChecker.isWithinRestriction(
              loc, DateTime(2025, 6, 15, 0, 0)),
          isTrue);
      expect(
          RestrictionChecker.isWithinRestriction(
              loc, DateTime(2025, 6, 20, 23, 59)),
          isTrue);
    });

    test('outside date range', () {
      expect(
          RestrictionChecker.isWithinRestriction(
              loc, DateTime(2025, 6, 9, 23, 59)),
          isFalse);
      expect(
          RestrictionChecker.isWithinRestriction(
              loc, DateTime(2025, 6, 21, 0, 0)),
          isFalse);
    });
  });

  group('RestrictionChecker – date range + time window', () {
    // 10–20 June, 09:00–17:00
    final loc = _loc(
      dateStart: DateTime(2025, 6, 10),
      dateEnd: DateTime(2025, 6, 20),
      startMin: 9 * 60,
      endMin: 17 * 60,
    );

    test('correct date AND inside time window', () {
      expect(
          RestrictionChecker.isWithinRestriction(
              loc, DateTime(2025, 6, 15, 9, 0)),
          isTrue);
      expect(
          RestrictionChecker.isWithinRestriction(
              loc, DateTime(2025, 6, 15, 16, 59)),
          isTrue);
    });

    test('correct date BUT outside time window', () {
      expect(
          RestrictionChecker.isWithinRestriction(
              loc, DateTime(2025, 6, 15, 8, 59)),
          isFalse);
      expect(
          RestrictionChecker.isWithinRestriction(
              loc, DateTime(2025, 6, 15, 17, 1)),
          isFalse);
    });

    test('wrong date', () {
      expect(
          RestrictionChecker.isWithinRestriction(
              loc, DateTime(2025, 6, 5, 12, 0)),
          isFalse);
    });
  });
}
