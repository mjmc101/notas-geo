import 'package:hive_flutter/hive_flutter.dart';
import '../models/saved_place.dart';

class PlacesService {
  static const String _boxName = 'saved_places';

  static Box<SavedPlace> getBox() => Hive.box<SavedPlace>(_boxName);

  static List<SavedPlace> getAll() =>
      getBox().values.toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  static Future<void> save(SavedPlace place) async {
    await getBox().put(place.id, place);
  }

  static Future<void> delete(String id) async {
    await getBox().delete(id);
  }
}
