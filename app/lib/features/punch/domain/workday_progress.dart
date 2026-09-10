import '../../../core/time/time_utils.dart';
import 'models.dart';

/// As quatro batidas de uma jornada, na ordem em que acontecem.
enum PunchStep {
  entry('Entrada'),
  breakStart('Saída para intervalo'),
  breakEnd('Retorno do intervalo'),
  exit('Saída final');

  const PunchStep(this.label);

  /// Rótulo curto usado na timeline e nos detalhes do dia.
  final String label;

  /// Texto do CTA quando este é o próximo passo da jornada.
  String get actionLabel => switch (this) {
    PunchStep.entry => 'Registrar entrada',
    PunchStep.breakStart => 'Registrar saída',
    PunchStep.breakEnd => 'Registrar retorno',
    PunchStep.exit => 'Registrar saída final',
  };
}

/// Estado da jornada como o usuário a percebe.
///
/// Deriva de [WorkDayStatus] — que continua sendo a verdade do domínio — mas
/// separa "trabalhando" de "em intervalo", que o status colapsa em `open` e
/// `paused`, e distingue um dia ainda não iniciado de um dia encerrado.
enum WorkdayPhase { notStarted, working, onBreak, finished, needsReview }

/// Leitura viva de uma jornada em um instante.
///
/// Este objeto não persiste nada e não substitui [WorkDaySummary.workedMinutes]
/// como total autoritativo: [closedMinutes] é copiado dele. O que se acrescenta
/// aqui é apenas o tempo decorrido do segmento ainda aberto, que existe só para
/// exibição e nunca chega ao timesheet.
final class WorkdayProgress {
  const WorkdayProgress({
    required this.phase,
    required this.registeredSteps,
    required this.closedMinutes,
    required this.runningWorkedMinutes,
    required this.targetMinutes,
    required this.phaseSince,
    required this.nextStep,
    required this.isLive,
  });

  final WorkdayPhase phase;

  /// Quantas das quatro batidas já existem (0..4).
  final int registeredSteps;

  /// Total autoritativo dos pares fechados, vindo do domínio.
  final int closedMinutes;

  /// Minutos decorridos dentro do período de trabalho ainda aberto.
  /// Zero fora de [WorkdayPhase.working]. Somente exibição.
  final int runningWorkedMinutes;

  /// Meta do dia vinda da jornada configurada, ou `null` quando o usuário
  /// ainda não definiu uma. Somente exibição: não altera nenhum total.
  final int? targetMinutes;

  /// Horário local da última batida registrada.
  final DateTime? phaseSince;

  /// Próxima batida esperada, ou `null` quando a jornada acabou.
  final PunchStep? nextStep;

  /// `true` quando a jornada é a de hoje e um segmento está aberto — ou seja,
  /// quando os contadores precisam avançar com o relógio.
  final bool isLive;

  /// Total a exibir no herói de tempo.
  int get displayedMinutes => closedMinutes + runningWorkedMinutes;

  /// Quanto falta para fechar a jornada combinada. Negativo indica tempo além
  /// da meta; `null` quando não há meta definida.
  int? get remainingMinutes {
    final target = targetMinutes;
    return target == null ? null : target - displayedMinutes;
  }

  /// Fração da meta já cumprida, entre 0 e 1, ou `null` sem meta.
  double? get goalFraction {
    final target = targetMinutes;
    if (target == null || target <= 0) return null;
    return (displayedMinutes / target).clamp(0.0, 1.0);
  }

  bool get reachedGoal {
    final remaining = remainingMinutes;
    return remaining != null && remaining <= 0;
  }

  bool get canRegister => nextStep != null && phase != WorkdayPhase.needsReview;
}

/// Traduz uma jornada em uma leitura viva para a interface.
///
/// Fica no domínio, e não dentro de um widget, para que o cálculo de tempo
/// continue tendo um único dono e possa ser testado sem árvore de widgets.
WorkdayProgress describeWorkday(
  WorkDaySummary day,
  DateTime nowLocal, {
  int? targetMinutes,
}) {
  final steps = day.punches.length;
  final lastPunch = day.punches.isEmpty ? null : day.punches.last;
  final last = lastPunch?.occurredAtLocal;

  final phase = switch (day.status) {
    WorkDayStatus.invalid => WorkdayPhase.needsReview,
    WorkDayStatus.empty => WorkdayPhase.notStarted,
    WorkDayStatus.open => WorkdayPhase.working,
    WorkDayStatus.paused => WorkdayPhase.onBreak,
    WorkDayStatus.complete => WorkdayPhase.finished,
  };

  // Um dia passado nunca "corre": um período aberto em 12/08 é pendência de
  // revisão, não jornada em andamento.
  final isToday = dateOnly(nowLocal) == dateOnly(day.date);
  final hasOpenSegment =
      phase == WorkdayPhase.working || phase == WorkdayPhase.onBreak;
  final isLive = isToday && hasOpenSegment && last != null;

  var elapsed = 0;
  if (isLive) {
    // O cálculo roda em instantes absolutos (UTC), nunca sobre
    // `occurredAtLocal`: aquele valor carrega o horário de parede da batida
    // com a flag UTC, e compará-lo com um `now` local injetaria o fuso do
    // aparelho no contador.
    final difference = nowLocal
        .toUtc()
        .difference(lastPunch!.occurredAtUtc)
        .inMinutes;
    elapsed = difference < 0 ? 0 : difference;
  }

  return WorkdayProgress(
    phase: phase,
    registeredSteps: steps,
    closedMinutes: day.workedMinutes,
    runningWorkedMinutes: phase == WorkdayPhase.working ? elapsed : 0,
    targetMinutes: targetMinutes,
    phaseSince: last,
    nextStep: phase == WorkdayPhase.needsReview || steps >= 4
        ? null
        : PunchStep.values[steps],
    isLive: isLive,
  );
}
