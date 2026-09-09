import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../domain/reminder.dart';

final class LocalNotificationService {
  LocalNotificationService._();

  static final instance = LocalNotificationService._();
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    try {
      final current = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(current.identifier));
    } catch (_) {
      // Fallback to timezone package default if a device timezone cannot be read.
    }
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(settings: const InitializationSettings(android: android, iOS: ios));
    _initialized = true;
  }

  Future<void> requestPermissions() async {
    await initialize();
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<void> rescheduleAll(List<ReminderConfig> reminders) async {
    await initialize();
    await _plugin.cancelAll();
    for (final reminder in reminders.where((item) => item.enabled)) {
      await schedule(reminder);
    }
  }

  Future<void> schedule(ReminderConfig reminder) async {
    await initialize();
    for (var weekday = DateTime.monday; weekday <= DateTime.sunday; weekday++) {
      if (!reminder.includesWeekday(weekday)) continue;
      final id = reminder.id * 10 + weekday;
      final when = _nextWeekdayTime(weekday, reminder.hour, reminder.minute);
      await _plugin.zonedSchedule(
        id: id,
        title: 'HoraFólio',
        body: reminder.label,
        scheduledDate: when,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'horafolio_reminders',
            'Lembretes de ponto',
            channelDescription: 'Lembretes configurados para registrar o ponto.',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  tz.TZDateTime _nextWeekdayTime(int weekday, int hour, int minute) {
    var candidate = tz.TZDateTime.now(tz.local);
    candidate = tz.TZDateTime(tz.local, candidate.year, candidate.month, candidate.day, hour, minute);
    while (candidate.weekday != weekday || !candidate.isAfter(tz.TZDateTime.now(tz.local))) {
      candidate = candidate.add(const Duration(days: 1));
      candidate = tz.TZDateTime(tz.local, candidate.year, candidate.month, candidate.day, hour, minute);
    }
    return candidate;
  }
}
