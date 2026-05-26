import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'note.g.dart';

@HiveType(typeId: 0)
class Note extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String description;

  @HiveField(3)
  bool isDone;

  @HiveField(4)
  DateTime createdAt;

  @HiveField(5)
  TimeAlert? timeAlert;

  @HiveField(6)
  LocationAlert? locationAlert;

  Note({
    String? id,
    required this.title,
    required this.description,
    this.isDone = false,
    DateTime? createdAt,
    this.timeAlert,
    this.locationAlert,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();
}

@HiveType(typeId: 1)
class TimeAlert {
  @HiveField(0)
  DateTime dateTime;

  @HiveField(1)
  bool isRecurring;

  // 'daily', 'weekly', 'monthly'
  @HiveField(2)
  String? recurringType;

  TimeAlert({
    required this.dateTime,
    this.isRecurring = false,
    this.recurringType,
  });
}

@HiveType(typeId: 2)
class LocationAlert {
  @HiveField(0)
  double latitude;

  @HiveField(1)
  double longitude;

  @HiveField(2)
  double radiusMeters;

  @HiveField(3)
  String? locationName;

  // Only trigger when location is reached during this time window
  @HiveField(4)
  TimeAlert? timeRestriction;

  @HiveField(5)
  bool triggered;

  LocationAlert({
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    this.locationName,
    this.timeRestriction,
    this.triggered = false,
  });
}
