import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import '../models/note.dart';

class NotificationService {
  static const String timeChannel = 'time_alerts';
  static const String locationChannel = 'location_alerts';

  static Future<void> init() async {
    await AwesomeNotifications().initialize(
      null,
      [
        NotificationChannel(
          channelKey: timeChannel,
          channelName: 'Avisos por Hora',
          channelDescription: 'Notificações agendadas por data/hora',
          defaultColor: const Color(0xFFC8F060),
          ledColor: const Color(0xFFC8F060),
          importance: NotificationImportance.High,
          channelShowBadge: true,
          playSound: true,
          enableVibration: true,
        ),
        NotificationChannel(
          channelKey: locationChannel,
          channelName: 'Avisos por Localização',
          channelDescription: 'Notificações quando chega a um local',
          defaultColor: const Color(0xFFC8F060),
          ledColor: const Color(0xFFC8F060),
          importance: NotificationImportance.High,
          channelShowBadge: true,
          playSound: true,
          enableVibration: true,
        ),
      ],
      debug: false,
    );
  }

  static Future<bool> requestPermissions() async {
    return AwesomeNotifications().requestPermissionToSendNotifications();
  }

  static int _notifId(String noteId) => noteId.hashCode.abs() % 2147483647;
  static int _locNotifId(String noteId) =>
      ('loc_$noteId').hashCode.abs() % 2147483647;

  static Future<void> scheduleTimeAlert(Note note) async {
    if (note.timeAlert == null) return;
    final alert = note.timeAlert!;
    final id = _notifId(note.id);

    await AwesomeNotifications().cancelSchedule(id);

    if (alert.isRecurring && alert.recurringType != null) {
      NotificationSchedule? schedule;
      switch (alert.recurringType) {
        case 'daily':
          schedule = NotificationCalendar(
            hour: alert.dateTime.hour,
            minute: alert.dateTime.minute,
            second: 0,
            repeats: true,
          );
        case 'weekly':
          schedule = NotificationCalendar(
            weekday: alert.dateTime.weekday,
            hour: alert.dateTime.hour,
            minute: alert.dateTime.minute,
            second: 0,
            repeats: true,
          );
        case 'monthly':
          schedule = NotificationCalendar(
            day: alert.dateTime.day,
            hour: alert.dateTime.hour,
            minute: alert.dateTime.minute,
            second: 0,
            repeats: true,
          );
      }
      if (schedule != null) {
        await AwesomeNotifications().createNotification(
          content: NotificationContent(
            id: id,
            channelKey: timeChannel,
            title: note.title,
            body: note.description.isNotEmpty ? note.description : 'Lembrete',
            notificationLayout: NotificationLayout.Default,
          ),
          schedule: schedule,
        );
      }
    } else if (alert.dateTime.isAfter(DateTime.now())) {
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: id,
          channelKey: timeChannel,
          title: note.title,
          body: note.description.isNotEmpty ? note.description : 'Lembrete',
          notificationLayout: NotificationLayout.Default,
        ),
        schedule: NotificationCalendar.fromDate(
          date: alert.dateTime,
          repeats: false,
        ),
      );
    }
  }

  static Future<void> sendLocationAlert(Note note) async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: _locNotifId(note.id),
        channelKey: locationChannel,
        title: note.title,
        body: note.locationAlert?.locationName != null
            ? 'Chegou a: ${note.locationAlert!.locationName}'
            : 'Chegou ao local da nota',
        notificationLayout: NotificationLayout.Default,
      ),
    );
  }

  static Future<void> cancelNoteNotifications(String noteId) async {
    await AwesomeNotifications().cancel(_notifId(noteId));
    await AwesomeNotifications().cancel(_locNotifId(noteId));
  }
}
