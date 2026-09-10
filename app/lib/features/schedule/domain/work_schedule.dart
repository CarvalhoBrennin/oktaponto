/// Como o intervalo acontece no dia a dia.
enum BreakMode {
  /// Sempre no mesmo horário (12:00 às 13:00, por exemplo).
  fixed,

  /// A qualquer hora; o que está combinado é a duração.
  flexible,
}

/// A jornada combinada do usuário.
///
/// É configuração de comportamento, não dado de ponto: nada aqui entra no
/// timesheet nem no histórico. Serve para o app saber quando lembrar de bater
/// o ponto e qual é a meta do dia.
///
/// Horários são guardados como minutos desde a meia-noite para o domínio não
/// depender de `TimeOfDay` nem de fuso.
final class WorkSchedule {
  const WorkSchedule({
    required this.startMinuteOfDay,
    required this.endMinuteOfDay,
    required this.breakMode,
    required this.breakStartMinuteOfDay,
    required this.breakMinutes,
    required this.weekdaysMask,
    required this.leadMinutes,
    required this.remindersEnabled,
  });

  /// Ponto de partida da configuração inicial: 09:00 às 18:00, uma hora de
  /// almoço ao meio-dia, de segunda a sexta.
  static const defaults = WorkSchedule(
    startMinuteOfDay: 9 * 60,
    endMinuteOfDay: 18 * 60,
    breakMode: BreakMode.fixed,
    breakStartMinuteOfDay: 12 * 60,
    breakMinutes: 60,
    weekdaysMask: 31,
    leadMinutes: 10,
    remindersEnabled: true,
  );

  final int startMinuteOfDay;
  final int endMinuteOfDay;
  final BreakMode breakMode;

  /// Só tem significado quando [breakMode] é [BreakMode.fixed].
  final int breakStartMinuteOfDay;

  final int breakMinutes;

  /// Bitmask de dias da semana, com segunda-feira no bit 0.
  final int weekdaysMask;

  /// Com quantos minutos de antecedência avisar.
  final int leadMinutes;

  final bool remindersEnabled;

  /// Meta diária: o tempo entre entrada e saída, menos o intervalo.
  int get targetMinutes => endMinuteOfDay - startMinuteOfDay - breakMinutes;

  bool includesWeekday(int weekday) =>
      (weekdaysMask & (1 << (weekday - 1))) != 0;

  /// Primeiro problema que impede usar esta jornada, ou `null` se está ok.
  ///
  /// A regra de meia-noite vem do domínio de ponto: o app não infere jornada
  /// que atravessa o dia, então uma jornada configurada assim seria impossível
  /// de registrar.
  String? get problem {
    if (endMinuteOfDay <= startMinuteOfDay) {
      return 'A saída precisa ser depois da entrada. Jornada que atravessa a '
          'meia-noite ainda não é suportada.';
    }
    if (breakMinutes < 0) {
      return 'O intervalo não pode ser negativo.';
    }
    if (targetMinutes <= 0) {
      return 'O intervalo não cabe entre a entrada e a saída.';
    }
    if (breakMode == BreakMode.fixed) {
      if (breakStartMinuteOfDay < startMinuteOfDay) {
        return 'O intervalo começa antes da entrada.';
      }
      if (breakStartMinuteOfDay + breakMinutes > endMinuteOfDay) {
        return 'O intervalo termina depois da saída.';
      }
    }
    if (remindersEnabled && weekdaysMask == 0) {
      return 'Escolha pelo menos um dia da semana para os lembretes.';
    }
    if (leadMinutes < 0 || leadMinutes > 60) {
      return 'A antecedência do aviso precisa ficar entre 0 e 60 minutos.';
    }
    return null;
  }

  bool get isValid => problem == null;

  WorkSchedule copyWith({
    int? startMinuteOfDay,
    int? endMinuteOfDay,
    BreakMode? breakMode,
    int? breakStartMinuteOfDay,
    int? breakMinutes,
    int? weekdaysMask,
    int? leadMinutes,
    bool? remindersEnabled,
  }) {
    return WorkSchedule(
      startMinuteOfDay: startMinuteOfDay ?? this.startMinuteOfDay,
      endMinuteOfDay: endMinuteOfDay ?? this.endMinuteOfDay,
      breakMode: breakMode ?? this.breakMode,
      breakStartMinuteOfDay:
          breakStartMinuteOfDay ?? this.breakStartMinuteOfDay,
      breakMinutes: breakMinutes ?? this.breakMinutes,
      weekdaysMask: weekdaysMask ?? this.weekdaysMask,
      leadMinutes: leadMinutes ?? this.leadMinutes,
      remindersEnabled: remindersEnabled ?? this.remindersEnabled,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'startMinuteOfDay': startMinuteOfDay,
    'endMinuteOfDay': endMinuteOfDay,
    'breakMode': breakMode.name,
    'breakStartMinuteOfDay': breakStartMinuteOfDay,
    'breakMinutes': breakMinutes,
    'weekdaysMask': weekdaysMask,
    'leadMinutes': leadMinutes,
    'remindersEnabled': remindersEnabled,
  };

  /// Lê a jornada gravada, caindo em [defaults] campo a campo.
  ///
  /// Tolerante de propósito: uma configuração corrompida ou de uma versão
  /// futura vira uma jornada utilizável em vez de derrubar a abertura do app.
  static WorkSchedule fromJson(Map<String, Object?> json) {
    int readInt(String key, int fallback) {
      final value = json[key];
      return value is int ? value : fallback;
    }

    return WorkSchedule(
      startMinuteOfDay: readInt('startMinuteOfDay', defaults.startMinuteOfDay),
      endMinuteOfDay: readInt('endMinuteOfDay', defaults.endMinuteOfDay),
      breakMode: BreakMode.values.firstWhere(
        (mode) => mode.name == json['breakMode'],
        orElse: () => defaults.breakMode,
      ),
      breakStartMinuteOfDay: readInt(
        'breakStartMinuteOfDay',
        defaults.breakStartMinuteOfDay,
      ),
      breakMinutes: readInt('breakMinutes', defaults.breakMinutes),
      weekdaysMask: readInt('weekdaysMask', defaults.weekdaysMask),
      leadMinutes: readInt('leadMinutes', defaults.leadMinutes),
      remindersEnabled:
          json['remindersEnabled'] as bool? ?? defaults.remindersEnabled,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is WorkSchedule &&
      other.startMinuteOfDay == startMinuteOfDay &&
      other.endMinuteOfDay == endMinuteOfDay &&
      other.breakMode == breakMode &&
      other.breakStartMinuteOfDay == breakStartMinuteOfDay &&
      other.breakMinutes == breakMinutes &&
      other.weekdaysMask == weekdaysMask &&
      other.leadMinutes == leadMinutes &&
      other.remindersEnabled == remindersEnabled;

  @override
  int get hashCode => Object.hash(
    startMinuteOfDay,
    endMinuteOfDay,
    breakMode,
    breakStartMinuteOfDay,
    breakMinutes,
    weekdaysMask,
    leadMinutes,
    remindersEnabled,
  );
}

/// O que o app sabe sobre a configuração inicial.
///
/// [schedule] nulo significa que o usuário nunca definiu a jornada — seja
/// porque ainda não abriu o app, seja porque pulou a apresentação. Nesse caso
/// não existe meta do dia e nenhum lembrete automático é agendado.
final class ScheduleSetup {
  const ScheduleSetup({required this.onboardingSeen, required this.schedule});

  static const initial = ScheduleSetup(onboardingSeen: false, schedule: null);

  final bool onboardingSeen;
  final WorkSchedule? schedule;

  bool get needsOnboarding => !onboardingSeen;

  /// Meta do dia em minutos, ou `null` quando não há jornada definida.
  int? get targetMinutes {
    final current = schedule;
    if (current == null || !current.isValid) return null;
    return current.targetMinutes;
  }
}
