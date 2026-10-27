import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../schedule/domain/schedule_reminders.dart';
import '../domain/reminder.dart';

/// Faixas de identificador das notificações.
///
/// Os avisos recorrentes são recriados a cada reagendamento; o de fim de
/// intervalo nasce de uma batida real e precisa sobreviver a esse ciclo, então
/// mora numa faixa própria que o reagendamento não toca.
const _manualBase = 0;
const _scheduleBase = 800000;
const _dynamicBase = 900000;
const _breakDueId = _dynamicBase;
const _breakFollowUpId = _dynamicBase + 1;

final class LocalNotificationService {
  LocalNotificationService._();

  static final instance = LocalNotificationService._();
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  Future<void> _rescheduleQueue = Future<void>.value();
  bool _pluginInitialized = false;
  bool _timezoneReady = false;
  Object? _timezoneError;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'oktaponto_reminders',
      'Lembretes de ponto',
      channelDescription: 'Lembretes configurados para registrar o ponto.',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  Future<void> initialize() async {
    if (!_pluginInitialized) {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const windows = WindowsInitializationSettings(
        appName: 'OktaPonto',
        appUserModelId: 'com.oktaponto.app',
        guid: 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d',
      );
      const linux = LinuxInitializationSettings(defaultActionName: 'Abrir');
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: android,
          iOS: ios,
          macOS: ios,
          windows: windows,
          linux: linux,
        ),
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

  /// Synchronizes recurring reminders from both the work schedule and the
  /// manual reminder list.
  ///
  /// Both sets share one scheduler, so independently calling `cancelAll`
  /// would let the last caller erase the other set. Serialize reconciliations
  /// so their scheduling and cleanup steps cannot interleave.
  Future<void> rescheduleAll(
    List<ReminderConfig> reminders, {
    List<ScheduleReminder> scheduleReminders = const [],
    int scheduleWeekdaysMask = 0,
  }) {
    final reminderSnapshot = List<ReminderConfig>.unmodifiable(reminders);
    final scheduleSnapshot = List<ScheduleReminder>.unmodifiable(
      scheduleReminders,
    );
    final operation = _rescheduleQueue.then<void>(
      (_) => _applyReschedule(
        reminderSnapshot,
        scheduleReminders: scheduleSnapshot,
        scheduleWeekdaysMask: scheduleWeekdaysMask,
      ),
    );
    _rescheduleQueue = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> _applyReschedule(
    List<ReminderConfig> reminders, {
    required List<ScheduleReminder> scheduleReminders,
    required int scheduleWeekdaysMask,
  }) async {
    await initialize();
    final enabled = reminders.where((item) => item.enabled).toList();
    if (enabled.isNotEmpty || scheduleReminders.isNotEmpty) {
      await _requireTimezone();
    }
    final desiredIds = <int>{};
    for (final reminder in enabled) {
      desiredIds.addAll(
        _weeklyIds(idBase: reminder.id * 10, mask: reminder.weekdaysMask),
      );
      await schedule(reminder);
    }
    for (final reminder in scheduleReminders) {
      desiredIds.addAll(
        _weeklyIds(
          idBase: _scheduleBase + reminder.slot * 10,
          mask: scheduleWeekdaysMask,
        ),
      );
      await _scheduleFromWorkday(reminder, scheduleWeekdaysMask);
    }
    await _cancelRecurringExcept(desiredIds);
  }

  /// Limpa só a faixa recorrente, preservando o aviso de fim de intervalo que
  /// possa estar pendente para o dia de hoje.
  Future<void> _cancelRecurringExcept(Set<int> retainedIds) async {
    final pending = await _plugin.pendingNotificationRequests();
    for (final request in pending) {
      if (request.id >= _manualBase &&
          request.id < _dynamicBase &&
          !retainedIds.contains(request.id)) {
        await _plugin.cancel(id: request.id);
      }
    }
  }

  Set<int> _weeklyIds({required int idBase, required int mask}) {
    return {
      for (var weekday = DateTime.monday; weekday <= DateTime.sunday; weekday++)
        if ((mask & (1 << (weekday - 1))) != 0) idBase + weekday,
    };
  }

  Future<void> schedule(ReminderConfig reminder) async {
    await _requireTimezone();
    await _scheduleWeekly(
      idBase: reminder.id * 10,
      mask: reminder.weekdaysMask,
      hour: reminder.hour,
      minute: reminder.minute,
      body: reminder.label,
    );
  }

  Future<void> _scheduleFromWorkday(
    ScheduleReminder reminder,
    int weekdaysMask,
  ) async {
    await _requireTimezone();
    await _scheduleWeekly(
      idBase: _scheduleBase + reminder.slot * 10,
      mask: weekdaysMask,
      hour: reminder.hour,
      minute: reminder.minute,
      body: reminder.message,
    );
  }

  Future<void> _scheduleWeekly({
    required int idBase,
    required int mask,
    required int hour,
    required int minute,
    required String body,
  }) async {
    for (var weekday = DateTime.monday; weekday <= DateTime.sunday; weekday++) {
      if ((mask & (1 << (weekday - 1))) == 0) continue;
      await _plugin.zonedSchedule(
        id: idBase + weekday,
        title: 'OktaPonto',
        body: body,
        scheduledDate: _nextWeekdayTime(weekday, hour, minute),
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  /// Agenda o aviso de fim de intervalo a partir da batida real.
  ///
  /// São dois disparos: o do horário exato e uma única insistência, para o
  /// caso de o primeiro passar batido. Ambos são cancelados assim que o
  /// retorno é registrado.
  Future<void> scheduleBreakReminder(BreakReminderPlan plan) async {
    await _requireTimezone();
    await cancelBreakReminder();
    final now = tz.TZDateTime.now(tz.local);
    Future<void> arm(int id, DateTime when, String body) async {
      final target = tz.TZDateTime.from(when, tz.local);
      // Um horário já vencido não é reagendado: o plugin dispararia na hora e
      // o usuário levaria um susto ao abrir o app.
      if (!target.isAfter(now)) return;
      await _plugin.zonedSchedule(
        id: id,
        title: 'OktaPonto',
        body: body,
        scheduledDate: target,
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }

    await arm(
      _breakDueId,
      plan.dueAt,
      'Seu intervalo terminou. Registre o retorno.',
    );
    await arm(
      _breakFollowUpId,
      plan.followUpAt,
      'O retorno do intervalo ainda não foi registrado.',
    );
  }

  Future<void> cancelBreakReminder() async {
    await initialize();
    await _plugin.cancel(id: _breakDueId);
    await _plugin.cancel(id: _breakFollowUpId);
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
