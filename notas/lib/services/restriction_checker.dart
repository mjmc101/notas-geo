import '../models/note.dart';

/// Pure logic for checking whether a [LocationAlert] restriction allows
/// a notification to fire at [now]. No Flutter/plugin dependencies so it
/// can be unit-tested directly.
class RestrictionChecker {
  const RestrictionChecker._();

  static bool isWithinRestriction(LocationAlert loc, DateTime now) {
    if (!loc.hasRestriction) return true;

    // ── Date restriction ─────────────────────────────────────────────────
    if (loc.dateRangeStart != null) {
      final startDay = _dateOnly(loc.dateRangeStart!);
      final nowDay = _dateOnly(now);

      if (nowDay.isBefore(startDay)) return false;

      if (loc.dateRangeEnd != null) {
        final endDay = _dateOnly(loc.dateRangeEnd!);
        if (nowDay.isAfter(endDay)) return false;
      } else {
        // Single day: only that exact calendar date
        if (nowDay.isAfter(startDay)) return false;
      }
    }

    // ── Time-of-day window ────────────────────────────────────────────────
    if (loc.hasTimeWindow) {
      final nowMin = now.hour * 60 + now.minute;
      final start = loc.timeWindowStartMinutes!;
      final end = loc.timeWindowEndMinutes!;

      if (start <= end) {
        if (nowMin < start || nowMin > end) return false;
      } else {
        // Overnight range, e.g. 22:00–06:00
        if (nowMin < start && nowMin > end) return false;
      }
    }

    return true;
  }

  static DateTime _dateOnly(DateTime dt) =>
      DateTime(dt.year, dt.month, dt.day);
}
