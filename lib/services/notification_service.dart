import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
import '../data/strength_program.dart';
import 'storage_service.dart';

/// Rappels locaux (course + KB) — un rappel non déclenché est reprogrammé
/// pour le lendemain ; il est annulé dès que la séance correspondante est faite.
class NotificationService {
  static const runReminderId = 1001;
  static const kbReminderId = 1002;

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static Future<void> _ensureReady() async {
    if (_ready) return;
    tz_data.initializeTimeZones();
    // Approximation par décalage horaire fixe (pas de dépendance native pour l'IANA tz name)
    final offsetHours = DateTime.now().timeZoneOffset.inHours;
    final locationName =
        offsetHours == 0 ? 'UTC' : 'Etc/GMT${offsetHours > 0 ? '-' : '+'}${offsetHours.abs()}';
    try {
      tz.setLocalLocation(tz.getLocation(locationName));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }

    await _plugin.initialize(
      settings: const InitializationSettings(
        iOS: DarwinInitializationSettings(),
        macOS: DarwinInitializationSettings(),
      ),
    );
    _ready = true;
  }

  static Future<bool> requestPermission() async {
    await _ensureReady();
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    final mac = _plugin.resolvePlatformSpecificImplementation<
        MacOSFlutterLocalNotificationsPlugin>();
    final granted = await ios?.requestPermissions(alert: true, badge: true, sound: true) ??
        await mac?.requestPermissions(alert: true, badge: true, sound: true);
    return granted ?? false;
  }

  static Future<void> cancelReminder(int id) async {
    await _ensureReady();
    await _plugin.cancel(id: id);
  }

  static Future<void> _scheduleReminder({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    await _ensureReady();
    await _plugin.cancel(id: id);

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!scheduled.isAfter(now)) scheduled = scheduled.add(const Duration(days: 1));

    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduled,
      notificationDetails: const NotificationDetails(
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  /// Reprogramme les rappels course/KB selon l'état du jour — à appeler
  /// après chargement des écrans et après chaque changement de réglage.
  static Future<void> refresh() async {
    final enabled = await StorageService.getRemindersEnabled();
    if (!enabled) {
      await cancelReminder(runReminderId);
      await cancelReminder(kbReminderId);
      return;
    }
    await requestPermission();

    final hour = await StorageService.getReminderHour();
    final minute = await StorageService.getReminderMinute();

    final completedToday = await StorageService.wasCompletedToday();
    if (completedToday) {
      await cancelReminder(runReminderId);
    } else {
      await _scheduleReminder(
        id: runReminderId,
        title: 'Séance en attente',
        body: 'Ta séance de course du jour t\'attend.',
        hour: hour,
        minute: minute,
      );
    }

    final workoutLogs = await StorageService.getWorkoutLogs();
    final today = DateTime.now();
    final kbDoneToday = workoutLogs.any((l) =>
        l.date.year == today.year && l.date.month == today.month && l.date.day == today.day);

    if (kbDoneToday || strengthProgram.isEmpty) {
      await cancelReminder(kbReminderId);
    } else {
      final currentDay = await StorageService.getCurrentDay();
      final workout = mixedWorkoutForDay(currentDay);
      await _scheduleReminder(
        id: kbReminderId,
        title: 'Renfo kettlebell',
        body: '${workout.title} t\'attend.',
        hour: hour,
        minute: minute,
      );
    }
  }
}
