import 'package:hive_flutter/hive_flutter.dart';
import '../models/note.dart';
import '../models/saved_place.dart';

class HiveService {
  static const String _notesBox = 'notes';

  static Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(NoteAdapter());
    Hive.registerAdapter(TimeAlertAdapter());
    Hive.registerAdapter(LocationAlertAdapter());
    Hive.registerAdapter(SavedPlaceAdapter());
    await Hive.openBox<Note>(_notesBox);
    await Hive.openBox<SavedPlace>('saved_places');
  }

  static Box<Note> getNotesBox() => Hive.box<Note>(_notesBox);

  static List<Note> getAllNotes() {
    return getNotesBox().values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  static Future<void> saveNote(Note note) async {
    await getNotesBox().put(note.id, note);
  }

  static Future<void> deleteNote(String id) async {
    await getNotesBox().delete(id);
  }
}
