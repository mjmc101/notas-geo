// Round-trip and robustness tests for BackupService (pure, no plugins).
import 'package:flutter_test/flutter_test.dart';
import 'package:notas/models/note.dart';
import 'package:notas/models/saved_place.dart';
import 'package:notas/services/backup_service.dart';

void main() {
  group('BackupService.encode/decode', () {
    test('empty collections round-trip to empty', () {
      final json = BackupService.encode(const [], const []);
      final data = BackupService.decode(json);
      expect(data.notes, isEmpty);
      expect(data.places, isEmpty);
      expect(data.exportedAt, isNotNull);
    });

    test('a plain note round-trips its scalar fields', () {
      final created = DateTime(2026, 1, 2, 3, 4, 5);
      final note = Note(
        id: 'n1',
        title: 'Comprar adubo',
        description: 'Loja agrícola',
        isDone: true,
        isArchived: true,
        createdAt: created,
      );

      final data = BackupService.decode(BackupService.encode([note], const []));

      expect(data.notes, hasLength(1));
      final back = data.notes.single;
      expect(back.id, 'n1');
      expect(back.title, 'Comprar adubo');
      expect(back.description, 'Loja agrícola');
      expect(back.isDone, isTrue);
      expect(back.isArchived, isTrue);
      expect(back.createdAt, created);
    });

    test('time alert (recurring) round-trips', () {
      final dt = DateTime(2026, 5, 10, 8, 30);
      final note = Note(
        id: 'n2',
        title: 'Regar',
        description: '',
        timeAlert:
            TimeAlert(dateTime: dt, isRecurring: true, recurringType: 'daily'),
      );

      final back = BackupService.decode(
        BackupService.encode([note], const []),
      ).notes.single;

      expect(back.timeAlert, isNotNull);
      expect(back.timeAlert!.dateTime, dt);
      expect(back.timeAlert!.isRecurring, isTrue);
      expect(back.timeAlert!.recurringType, 'daily');
    });

    test('location alert with restrictions round-trips', () {
      final start = DateTime(2026, 6, 1);
      final end = DateTime(2026, 6, 30);
      final note = Note(
        id: 'n3',
        title: 'Estufa',
        description: '',
        locationAlert: LocationAlert(
          latitude: 39.8075,
          longitude: -8.0883,
          radiusMeters: 150,
          locationName: 'Sertã',
          timeWindowStartMinutes: 540,
          timeWindowEndMinutes: 1080,
          dateRangeStart: start,
          dateRangeEnd: end,
        ),
      );

      final back = BackupService.decode(
        BackupService.encode([note], const []),
      ).notes.single;

      final loc = back.locationAlert!;
      expect(loc.latitude, closeTo(39.8075, 1e-9));
      expect(loc.longitude, closeTo(-8.0883, 1e-9));
      expect(loc.radiusMeters, 150);
      expect(loc.locationName, 'Sertã');
      expect(loc.timeWindowStartMinutes, 540);
      expect(loc.timeWindowEndMinutes, 1080);
      expect(loc.dateRangeStart, start);
      expect(loc.dateRangeEnd, end);
    });

    test('null alerts stay null', () {
      final note = Note(id: 'n4', title: 'X', description: '');
      final back = BackupService.decode(
        BackupService.encode([note], const []),
      ).notes.single;
      expect(back.timeAlert, isNull);
      expect(back.locationAlert, isNull);
    });

    test('saved places round-trip', () {
      final place =
          SavedPlace(id: 'p1', name: 'Horta', latitude: 39.8, longitude: -8.08);
      final back = BackupService.decode(
        BackupService.encode(const [], [place]),
      ).places.single;
      expect(back.id, 'p1');
      expect(back.name, 'Horta');
      expect(back.latitude, closeTo(39.8, 1e-9));
      expect(back.longitude, closeTo(-8.08, 1e-9));
    });
  });

  group('BackupService.decode robustness', () {
    test('throws on non-JSON input', () {
      expect(() => BackupService.decode('not json {'),
          throwsA(isA<FormatException>()));
    });

    test('throws on JSON that is not a backup object', () {
      expect(() => BackupService.decode('[1, 2, 3]'),
          throwsA(isA<FormatException>()));
    });

    test('throws when the "notes" key is missing', () {
      expect(() => BackupService.decode('{"places": []}'),
          throwsA(isA<FormatException>()));
    });

    test('tolerates a missing "places" key', () {
      final data = BackupService.decode('{"notes": []}');
      expect(data.notes, isEmpty);
      expect(data.places, isEmpty);
    });
  });
}
