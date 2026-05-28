import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'saved_place.g.dart';

@HiveType(typeId: 3)
class SavedPlace extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  double latitude;

  @HiveField(3)
  double longitude;

  SavedPlace({
    String? id,
    required this.name,
    required this.latitude,
    required this.longitude,
  }) : id = id ?? const Uuid().v4();
}
