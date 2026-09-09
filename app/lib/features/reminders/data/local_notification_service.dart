import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../domain/reminder.dart';

final class LocalNotificationService {
  LocalNotificationService._();

  static final instance = LocalNotificationService._();
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _pluginInitialized = false;
  bool _timezoneReady = false;
  Object? _timezoneError;

  Future<void> initialize() async {
    if (!_pluginInitialized) {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await _plugin.initialize(
        settings: const InitializationSettings(android: android, iOS: ios),
      );
      _pluginInitialized = true;
    }
    await _tryInitializeTimezone();
  }

  Future<void> _tryInitializeTimezone() async {
    if (_timezoneReady) return;
    tz_data.initializeTimeZones();
    try {
      final current = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(current.identifier));
      _timezoneReady = true;
      _timezoneError = null;
    } catch (error) {
      _timezoneError = error;
    }
  }

  Future<void> _requireTimezone() async {
    await initialize();
    if (_timezoneReady) return;
    await _tryInitializeTimezone();
    if (!_timezoneReady) {
      throw StateError(
        'Não foi possível identificar o fuso horário do dispositivo. '
        'Os lembretes não foram alterados para evitar horários incorretos. '
        'Detalhe: ${_timezoneError ?? 'desconhecido'}',
      );
    }
  }

  Future<bool> requestPermissions() async {
    await initialize();
    bool? granted;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      granted = await android.requestNotificationsPermission() ?? true;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      granted =
          await ios.requestPermissions(alert: true, badge: true, sound: true) ??
          true;
    }
    // Platforms without a runtime notification permission API are treated as
    // granted; scheduling can still fail and that failure is surfaced.
    return granted ?? true;
  }

  Future<void> cancelAll() async {
    await initialize();
    await _plugin.cancelAll();
  }

  Future<void> rescheduleAll(List<ReminderConfig> reminders) async {
    await initialize();
    final enabled = reminders.where((item) => item.enabled).toList();
    if (enabled.isNotEmpty) {
      await _requireTimezone();
    }
    await _plugin.cancelAll();
    for (final reminder in enabled) {
      await schedule(reminder);
    }
  }

  Future<void> schedule(ReminderConfig reminder) async {
    await _requireTimezone();
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
            channelDescription:
                'Lembretes configurados para registrar o ponto.',
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
    final now = tz.TZDateTime.now(tz.local);
    var candidate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    while (candidate.weekday != weekday || !candidate.isAfter(now)) {
      final nextDay = candidate.add(const Duration(days: 1));
      candidate = tz.TZDateTime(
        tz.local,
        nextDay.year,
        nextDay.month,
        nextDay.day,
        hour,
        minute,
      );
    }
    return candidate;
  }
}
