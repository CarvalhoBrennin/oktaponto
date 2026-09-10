import 'package:flutter/material.dart';

import '../../../core/design/hf_semantics.dart';
import '../domain/models.dart';
import '../domain/workday_progress.dart';

/// Como um estado da jornada se apresenta: papel de cor, ícone e rótulo.
///
/// Um único lugar traduz domínio em aparência, para que "trabalhando" tenha a
/// mesma cor, o mesmo ícone e a mesma palavra em Hoje, Histórico e Fechamento.
@immutable
final class WorkdayVisual {
  const WorkdayVisual({
    required this.role,
    required this.icon,
    required this.label,
  });

  final HfRole role;
  final IconData icon;
  final String label;
}

/// Aparência da fase corrente da jornada de hoje.
WorkdayVisual visualForPhase(HfSemantics hf, WorkdayPhase phase) {
  return switch (phase) {
    WorkdayPhase.notStarted => WorkdayVisual(
      role: hf.idle,
      icon: Icons.schedule_outlined,
      label: 'Jornada não iniciada',
    ),
    WorkdayPhase.working => WorkdayVisual(
      role: hf.working,
      icon: Icons.play_arrow_rounded,
      label: 'Trabalhando',
    ),
    WorkdayPhase.onBreak => WorkdayVisual(
      role: hf.resting,
      icon: Icons.pause_rounded,
      label: 'Em intervalo',
    ),
    WorkdayPhase.finished => WorkdayVisual(
      role: hf.done,
      icon: Icons.check_rounded,
      label: 'Jornada concluída',
    ),
    WorkdayPhase.needsReview => WorkdayVisual(
      role: hf.attention,
      icon: Icons.priority_high_rounded,
      label: 'Precisa de revisão',
    ),
  };
}

/// Aparência de um dia no histórico e no fechamento, onde o que importa é se
/// o registro está completo, incompleto ou precisa de atenção.
WorkdayVisual visualForDay(HfSemantics hf, WorkDaySummary day) {
  if (day.status == WorkDayStatus.invalid || day.hasBlockingIssues) {
    return WorkdayVisual(
      role: hf.attention,
      icon: Icons.priority_high_rounded,
      label: 'Revisar',
    );
  }
  return switch (day.status) {
    WorkDayStatus.complete => WorkdayVisual(
      role: hf.done,
      icon: Icons.check_rounded,
      label: 'Completo',
    ),
    WorkDayStatus.empty => WorkdayVisual(
      role: hf.idle,
      icon: Icons.remove_rounded,
      label: 'Sem registro',
    ),
    // Um dia passado com período aberto não é "em andamento": é registro
    // incompleto, e é assim que precisa ser lido na lista. Usa a cor de
    // pendência, não a de intervalo — azul aqui leria como "em pausa", que é
    // exatamente o que este dia não é. A distinção entre "revisar" e
    // "incompleto" fica no ícone e na palavra, como em todo o resto.
    WorkDayStatus.open || WorkDayStatus.paused => WorkdayVisual(
      role: hf.attention,
      icon: Icons.more_horiz_rounded,
      label: 'Incompleto',
    ),
    WorkDayStatus.invalid => WorkdayVisual(
      role: hf.attention,
      icon: Icons.priority_high_rounded,
      label: 'Revisar',
    ),
  };
}

/// Ícone de cada batida na timeline.
IconData iconForStep(PunchStep step) => switch (step) {
  PunchStep.entry => Icons.login_rounded,
  PunchStep.breakStart => Icons.coffee_outlined,
  PunchStep.breakEnd => Icons.work_history_outlined,
  PunchStep.exit => Icons.logout_rounded,
};

/// Como nomear a batida que ocupa uma posição da jornada.
///
/// Em um dia consistente, posição e tipo coincidem e vale o nome do passo.
/// Em um dia quebrado — apagar a entrada deixa uma saída solta na primeira
/// posição — chamar aquilo de "Entrada" mentiria justamente na tela onde o
/// usuário vai consertar. Nesses casos vale o tipo real da batida.
String labelForPunchAt(PunchStep step, Punch? punch) {
  if (punch == null) return step.label;
  final expected = step.index.isEven ? PunchKind.in_ : PunchKind.out;
  if (punch.kind == expected) return step.label;
  return punch.kind == PunchKind.in_ ? 'Entrada' : 'Saída';
}

/// Ícone coerente com [labelForPunchAt].
IconData iconForPunchAt(PunchStep step, Punch? punch) {
  if (punch == null) return iconForStep(step);
  final expected = step.index.isEven ? PunchKind.in_ : PunchKind.out;
  if (punch.kind == expected) return iconForStep(step);
  return punch.kind == PunchKind.in_
      ? Icons.login_rounded
      : Icons.logout_rounded;
}
