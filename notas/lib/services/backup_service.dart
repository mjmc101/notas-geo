// Pure, plugin-free backup (export/import) logic.
//
// Serialises every [Note] and [SavedPlace] to a stable, human-readable JSON
// document and parses it back. Keeping this free of Hive / file-system / plugin
// calls means the full round-trip can be unit-tested directly and the format is
// independent of the on-disk Hive layout (so a backup survives adapter changes).
import 'dart:convert';

import '../models/note.dart';
import '../models/saved_place.dart';

/// Result of decoding a backup document.
class BackupData {
  final List<Note> notes;
  final List<SavedPlace> places;
  final DateTime? exportedAt;

  const BackupData({
    required this.notes,
    required this.places,
    this.exportedAt,
  });
}

class BackupService {
  BackupService._();

  /// Bumped only when the JSON shape changes in a backwards-incompatible way.
  static const int formatVersion = 1;

  // ── Encode ──────────────────────────────────────────────────────────────────

  /// Serialises [notes] and [places] to a pretty-printed JSON string.
  static String encode(
    List<Note> notes,
    List<SavedPlace> places, {
    DateTime? exportedAt,
  }) {
    final doc = {
      'version': formatVersion,
      'exportedAt': (exportedAt ?? DateTime.now()).toIso8601String(),
      'notes': notes.map(_noteToMap).toList(),
      'places': places.map(_placeToMap).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(doc);
  }

  // ── Decode ──────────────────────────────────────────────────────────────────

  /// Parses a backup document produced by [encode].
  ///
  /// Throws [FormatException] if the input is not valid JSON or does not look
  /// like a Notas & Avisos backup.
  static BackupData decode(String source) {
    final Object? root;
    try {
      root = jsonDecode(source);
    } on FormatException catch (e) {
      throw FormatException('Ficheiro não é JSON válido: ${e.message}');
    }

    if (root is! Map<String, dynamic>) {
      throw const FormatException('Formato de backup inválido.');
    }
    if (!root.containsKey('notes')) {
      throw const FormatException(
          'Não parece um backup do Notas & Avisos (falta "notes").');
    }

    final notes = <Note>[];
    for (final item in (root['notes'] as List? ?? const [])) {
      notes.add(_noteFromMap(item as Map<String, dynamic>));
    }

    final places = <SavedPlace>[];
    for (final item in (root['places'] as List? ?? const [])) {
      places.add(_placeFromMap(item as Map<String, dynamic>));
    }

    return BackupData(
      notes: notes,
      places: places,
      exportedAt: _parseDate(root['exportedAt']),
    );
  }

  // ── Note ⇄ Map ───────────────────────────────────────────────────────────────

  static Map<String, dynamic> _noteToMap(Note n) => {
        'id': n.id,
        'title': n.title,
        'description': n.description,
        'isDone': n.isDone,
        'isArchived': n.isArchived,
        'createdAt': n.createdAt.toIso8601String(),
        'timeAlert': n.timeAlert == null ? null : _timeAlertToMap(n.timeAlert!),
        'locationAlert':
            n.locationAlert == null ? null : _locAlertToMap(n.locationAlert!),
      };

  static Note _noteFromMap(Map<String, dynamic> m) => Note(
        id: m['id'] as String?,
        title: (m['title'] as String?) ?? '',
        description: (m['description'] as String?) ?? '',
        isDone: (m['isDone'] as bool?) ?? false,
        isArchived: (m['isArchived'] as bool?) ?? false,
        createdAt: _parseDate(m['createdAt']),
        timeAlert: m['timeAlert'] == null
            ? null
            : _timeAlertFromMap(m['timeAlert'] as Map<String, dynamic>),
        locationAlert: m['locationAlert'] == null
            ? null
            : _locAlertFromMap(m['locationAlert'] as Map<String, dynamic>),
      );

  static Map<String, dynamic> _timeAlertToMap(TimeAlert a) => {
        'dateTime': a.dateTime.toIso8601String(),
        'isRecurring': a.isRecurring,
        'recurringType': a.recurringType,
      };

  static TimeAlert _timeAlertFromMap(Map<String, dynamic> m) => TimeAlert(
        dateTime: _parseDate(m['dateTime']) ?? DateTime.now(),
        isRecurring: (m['isRecurring'] as bool?) ?? false,
        recurringType: m['recurringType'] as String?,
      );

  static Map<String, dynamic> _locAlertToMap(LocationAlert l) => {
        'latitude': l.latitude,
        'longitude': l.longitude,
        'radiusMeters': l.radiusMeters,
        'locationName': l.locationName,
        'triggered': l.triggered,
        'timeWindowStartMinutes': l.timeWindowStartMinutes,
        'timeWindowEndMinutes': l.timeWindowEndMinutes,
        'dateRangeStart': l.dateRangeStart?.toIso8601String(),
        'dateRangeEnd': l.dateRangeEnd?.toIso8601String(),
      };

  static LocationAlert _locAlertFromMap(Map<String, dynamic> m) => LocationAlert(
        latitude: _toDouble(m['latitude']),
        longitude: _toDouble(m['longitude']),
        radiusMeters: _toDouble(m['radiusMeters']),
        locationName: m['locationName'] as String?,
        triggered: (m['triggered'] as bool?) ?? false,
        timeWindowStartMinutes: m['timeWindowStartMinutes'] as int?,
        timeWindowEndMinutes: m['timeWindowEndMinutes'] as int?,
        dateRangeStart: _parseDate(m['dateRangeStart']),
        dateRangeEnd: _parseDate(m['dateRangeEnd']),
      );

  // ── SavedPlace ⇄ Map ─────────────────────────────────────────────────────────

  static Map<String, dynamic> _placeToMap(SavedPlace p) => {
        'id': p.id,
        'name': p.name,
        'latitude': p.latitude,
        'longitude': p.longitude,
      };

  static SavedPlace _placeFromMap(Map<String, dynamic> m) => SavedPlace(
        id: m['id'] as String?,
        name: (m['name'] as String?) ?? '',
        latitude: _toDouble(m['latitude']),
        longitude: _toDouble(m['longitude']),
      );

  // ── Helpers ──────────────────────────────────────────────────────────────────

  static DateTime? _parseDate(Object? v) {
    if (v is! String || v.isEmpty) return null;
    return DateTime.tryParse(v);
  }

  static double _toDouble(Object? v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }
}
