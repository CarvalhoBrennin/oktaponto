final class ReminderConfig {
  const ReminderConfig({
    required this.id,
    required this.label,
    required this.hour,
    required this.minute,
    required this.weekdaysMask,
    required this.enabled,
  });

  final int id;
  final String label;
  final int hour;
  final int minute;
  final int weekdaysMask;
  final bool enabled;

  bool includesWeekday(int weekday) =>
      (weekdaysMask & (1 << (weekday - 1))) != 0;

  ReminderConfig copyWith({
    int? id,
    String? label,
    int? hour,
    int? minute,
    int? weekdaysMask,
    bool? enabled,
  }) {
    return ReminderConfig(
      id: id ?? this.id,
      label: label ?? this.label,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      weekdaysMask: weekdaysMask ?? this.weekdaysMask,
      enabled: enabled ?? this.enabled,
    );
  }
}
