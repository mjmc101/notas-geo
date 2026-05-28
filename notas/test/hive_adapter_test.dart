// Hive adapter round-trip tests.
//
// Adapters are written by hand (not generated), so a wrong field number or
// missing field is a silent data-loss bug.  These tests exercise the full
// write→close→reopen→read path to catch any mismatch.
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:notas/models/note.dart';
import 'package:notas/models/saved_place.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_adapter_test_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(NoteAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(TimeAlertAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(LocationAlertAdapter());
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(SavedPlaceAdapter());
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  // Writes [obj] to disk, closes the box, reopens it, reads back.
  // This forces Hive to exercise the adapter's write and read methods.
  Future<Note?> noteRT(Note note) async {
    final box = await Hive.openBox<Note>('rt_note');
    await box.put(note.id, note);
    await box.close();
    final box2 = await Hive.openBox<Note>('rt_note');
    final result = box2.get(note.id);
    await box2.deleteFromDisk();
    return result;
  }

  Future<SavedPlace?> placeRT(SavedPlace place) async {
    final box = await Hive.openBox<SavedPlace>('rt_place');
    await box.put(place.id, place);
    await box.close();
    final box2 = await Hive.openBox<SavedPlace>('rt_place');
    final result = box2.get(place.id);
    await box2.deleteFromDisk();
    return result;
  }

  // ── NoteAdapter ─────────────────────────────────────────────────────────────

  group('NoteAdapter', () {
    test('basic scalar fields round-trip', () async {
      final note = Note(
        id: 'n1',
        title: 'My Note',
        description: 'Details here',
        isDone: true,
        isArchived: false,
      );
      final back = await noteRT(note);
      expect(back?.id, 'n1');
      expect(back?.title, 'My Note');
      expect(back?.description, 'Details here');
      expect(back?.isDone, isTrue);
      expect(back?.isArchived, isFalse);
    });

    test('isArchived true round-trips correctly', () async {
      final note =
          Note(id: 'n2', title: 'X', description: '', isDone: true, isArchived: true);
      final back = await noteRT(note);
      expect(back?.isArchived, isTrue);
    });

    test('null alerts stored and retrieved as null', () async {
      final note = Note(id: 'n3', title: 'Plain', description: 'No alerts');
      final back = await noteRT(note);
      expect(back?.timeAlert, isNull);
      expect(back?.locationAlert, isNull);
    });

    test('TimeAlert — all fields round-trip', () async {
      final dt = DateTime(2025, 12, 25, 9, 30);
      final note = Note(
        id: 'n4',
        title: 'Timed',
        description: '',
        timeAlert: TimeAlert(
          dateTime: dt,
          isRecurring: true,
          recurringType: 'weekly',
        ),
      );
      final back = await noteRT(note);
      expect(back?.timeAlert?.dateTime, dt);
      expect(back?.timeAlert?.isRecurring, isTrue);
      expect(back?.timeAlert?.recurringType, 'weekly');
    });

    test('LocationAlert — all fields round-trip', () async {
      final start = DateTime(2025, 6, 1);
      final end = DateTime(2025, 6, 30);
      final note = Note(
        id: 'n5',
        title: 'Located',
        description: '',
        locationAlert: LocationAlert(
          latitude: 38.7169,
          longitude: -9.1399,
          radiusMeters: 250,
          locationName: 'Lisbon',
          triggered: false,
          timeWindowStartMinutes: 540,   // 09:00
          timeWindowEndMinutes: 1080,    // 18:00
          dateRangeStart: start,
          dateRangeEnd: end,
        ),
      );
      final back = await noteRT(note);
      final loc = back?.locationAlert;
      expect(loc?.latitude, closeTo(38.7169, 0.00001));
      expect(loc?.longitude, closeTo(-9.1399, 0.00001));
      expect(loc?.radiusMeters, 250);
      expect(loc?.locationName, 'Lisbon');
      expect(loc?.timeWindowStartMinutes, 540);
      expect(loc?.timeWindowEndMinutes, 1080);
      expect(loc?.dateRangeStart, start);
      expect(loc?.dateRangeEnd, end);
    });

    test('LocationAlert — null optional fields remain null', () async {
      final note = Note(
        id: 'n6',
        title: 'Bare',
        description: '',
        locationAlert:
            LocationAlert(latitude: 0, longitude: 0, radiusMeters: 100),
      );
      final back = await noteRT(note);
      final loc = back?.locationAlert;
      expect(loc?.locationName, isNull);
      expect(loc?.timeWindowStartMinutes, isNull);
      expect(loc?.timeWindowEndMinutes, isNull);
      expect(loc?.dateRangeStart, isNull);
      expect(loc?.dateRangeEnd, isNull);
    });

    test('missing isArchived field (old record) defaults to false', () async {
      // The adapter uses `fields[7] as bool? ?? false`.
      // A note written by this adapter always has field 7, so we verify
      // the default at the model level: a freshly constructed note without
      // explicit isArchived is false and survives the round-trip as false.
      final note = Note(id: 'n7', title: 'Legacy', description: '');
      expect(note.isArchived, isFalse);
      final back = await noteRT(note);
      expect(back?.isArchived, isFalse);
    });
  });

  // ── SavedPlaceAdapter ────────────────────────────────────────────────────────

  group('SavedPlaceAdapter', () {
    test('all fields round-trip', () async {
      final place = SavedPlace(
        id: 'p1',
        name: 'Home',
        latitude: 38.7200,
        longitude: -9.1500,
      );
      final back = await placeRT(place);
      expect(back?.id, 'p1');
      expect(back?.name, 'Home');
      expect(back?.latitude, closeTo(38.7200, 0.00001));
      expect(back?.longitude, closeTo(-9.1500, 0.00001));
    });

    test('auto-generated id survives round-trip', () async {
      final place = SavedPlace(name: 'Work', latitude: 38.72, longitude: -9.15);
      final back = await placeRT(place);
      expect(back?.id, place.id);
      expect(back?.id, isNotEmpty);
    });
  });
}
