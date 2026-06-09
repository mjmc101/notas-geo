// Tests for the pure note search/filter logic.
import 'package:flutter_test/flutter_test.dart';
import 'package:notas/models/note.dart';
import 'package:notas/services/note_filter.dart';

Note _note({
  required String id,
  String title = '',
  String description = '',
  bool isDone = false,
  bool withTime = false,
  bool withLocation = false,
}) {
  return Note(
    id: id,
    title: title,
    description: description,
    isDone: isDone,
    timeAlert: withTime ? TimeAlert(dateTime: DateTime(2026, 1, 1)) : null,
    locationAlert: withLocation
        ? LocationAlert(latitude: 0, longitude: 0, radiusMeters: 100)
        : null,
  );
}

void main() {
  final notes = [
    _note(id: '1', title: 'Comprar adubo', withTime: true),
    _note(id: '2', title: 'Regar estufa', withLocation: true),
    _note(id: '3', title: 'Podar macieira', isDone: true),
    _note(id: '4', title: 'Reunião', description: 'falar de adubo orgânico'),
  ];

  group('filter', () {
    test('all returns everything', () {
      expect(applyNoteFilter(notes, NoteListFilter.all, ''), hasLength(4));
    });

    test('time keeps only notes with a time alert', () {
      final r = applyNoteFilter(notes, NoteListFilter.time, '');
      expect(r.map((n) => n.id), ['1']);
    });

    test('location keeps only notes with a location alert', () {
      final r = applyNoteFilter(notes, NoteListFilter.location, '');
      expect(r.map((n) => n.id), ['2']);
    });

    test('done keeps only completed notes', () {
      final r = applyNoteFilter(notes, NoteListFilter.done, '');
      expect(r.map((n) => n.id), ['3']);
    });
  });

  group('search query', () {
    test('matches title case-insensitively', () {
      final r = applyNoteFilter(notes, NoteListFilter.all, 'REGAR');
      expect(r.map((n) => n.id), ['2']);
    });

    test('matches description', () {
      final r = applyNoteFilter(notes, NoteListFilter.all, 'orgânico');
      expect(r.map((n) => n.id), ['4']);
    });

    test('matches across multiple notes', () {
      final r = applyNoteFilter(notes, NoteListFilter.all, 'adubo');
      expect(r.map((n) => n.id), ['1', '4']);
    });

    test('preserves input order', () {
      final r = applyNoteFilter(notes, NoteListFilter.all, 'a');
      expect(r.map((n) => n.id).toList(), ['1', '2', '3', '4']);
    });

    test('empty result when nothing matches', () {
      expect(applyNoteFilter(notes, NoteListFilter.all, 'zzz'), isEmpty);
    });

    test('filter and query combine (AND)', () {
      // Only id 4 has "adubo" in its text but no time alert → time filter drops it.
      final r = applyNoteFilter(notes, NoteListFilter.time, 'adubo');
      expect(r.map((n) => n.id), ['1']);
    });
  });
}
