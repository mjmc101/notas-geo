// Pure, testable filtering + searching logic for the notes list.
//
// Kept out of the widget layer so the rules ("which notes match this filter
// and query") can be unit-tested without pumping any UI.
import '../models/note.dart';

/// Quick filters shown as chips above the notes list.
enum NoteListFilter {
  all('Todas'),
  time('Hora'),
  location('Local'),
  done('Concluídas');

  const NoteListFilter(this.label);

  /// Human label shown on the filter chip.
  final String label;
}

/// Returns the notes matching [filter] and the free-text [query].
///
/// [query] is matched case-insensitively against the title and description.
/// The returned list preserves the order of [notes].
List<Note> applyNoteFilter(
  List<Note> notes,
  NoteListFilter filter,
  String query,
) {
  final q = query.trim().toLowerCase();
  return notes.where((n) {
    if (!_matchesFilter(n, filter)) return false;
    if (q.isEmpty) return true;
    return n.title.toLowerCase().contains(q) ||
        n.description.toLowerCase().contains(q);
  }).toList();
}

bool _matchesFilter(Note n, NoteListFilter filter) {
  switch (filter) {
    case NoteListFilter.all:
      return true;
    case NoteListFilter.time:
      return n.timeAlert != null;
    case NoteListFilter.location:
      return n.locationAlert != null;
    case NoteListFilter.done:
      return n.isDone;
  }
}
