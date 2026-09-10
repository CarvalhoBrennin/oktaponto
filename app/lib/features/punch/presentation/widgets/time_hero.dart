import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/design/hf_semantics.dart';
import '../../../../core/design/hf_tokens.dart';
import '../../../../core/time/time_utils.dart';
import '../../domain/workday_progress.dart';
import '../workday_visuals.dart';

/// O herói de tempo da tela Hoje.
///
/// Um arco de 270° que responde "onde estou no dia?" antes mesmo de o texto
/// ser lido, assumindo a cor da fase atual. No centro ficam o total, o estado
/// e o horário em que ele começou.
///
/// O arco tem duas leituras, conforme o que o app sabe:
///
/// * com jornada configurada, mede o quanto da meta do dia já foi cumprido, e
///   fecha em verde quando ela é atingida;
/// * sem jornada, divide-se nos quatro registros e acende um segmento por
///   batida — porque inventar uma meta de horas que o usuário nunca informou
///   seria mentir sobre o domínio.
class TimeHero extends StatelessWidget {
  const TimeHero({super.key, required this.progress});

  final WorkdayProgress progress;

  @override
  Widget build(BuildContext context) {
    final hf = context.hf;
    final visual = visualForPhase(hf, progress.phase);

    // O anel acompanha o corpo de texto: com fonte ampliada ele cresce em vez
    // de espremer o conteúdo interno.
    final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
    final dial = math.min(
      HfSize.heroDial * scale.clamp(1.0, 1.35),
      HfSize.heroDialMax,
    );

    // Com jornada configurada o anel mede o quanto da meta já foi cumprido;
    // sem ela, mede quantos dos quatro registros existem. É a mesma pergunta
    // — "onde estou no dia?" — respondida com a melhor informação disponível.
    final goal = progress.goalFraction;
    final active = progress.reachedGoal
        ? hf.done.foreground
        : visual.role.foreground;

    final ring = SizedBox(
      width: dial,
      height: dial,
      child: TweenAnimationBuilder<double>(
        duration: HfMotion.slow,
        curve: HfMotion.standard,
        tween: Tween<double>(end: goal ?? progress.registeredSteps.toDouble()),
        builder: (context, value, child) => CustomPaint(
          painter: _JourneyDialPainter(
            value: value,
            segments: goal == null ? 4 : 1,
            active: active,
            track: hf.track,
            strokeWidth: dial * 0.055,
          ),
          child: child,
        ),
        child: Padding(
          padding: EdgeInsets.all(dial * 0.14),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: _HeroReadout(progress: progress, visual: visual),
            ),
          ),
        ),
      ),
    );

    return Semantics(
      container: true,
      label: _semanticLabel(),
      child: ExcludeSemantics(
        child: Center(
          // O arco de 270° deixa a base vazia; reservar o quadrado inteiro
          // abriria um vão morto entre o herói e o CTA.
          child: SizedBox(
            width: dial,
            height: dial * 0.86,
            child: OverflowBox(
              maxHeight: dial,
              alignment: Alignment.topCenter,
              child: ring,
            ),
          ),
        ),
      ),
    );
  }

  String _semanticLabel() {
    final since = progress.phaseSince;
    final buffer = StringBuffer(
      '${_spokenDuration(progress.displayedMinutes)}. '
      '${_phraseFor(progress)}',
    );
    if (since != null && progress.phase != WorkdayPhase.finished) {
      buffer.write(' desde ${formatClock(since)}');
    }
    buffer.write('. ${progress.registeredSteps} de 4 registros.');
    return buffer.toString();
  }
}

/// Duração falada, sem zeros à esquerda e sem partes que valem zero.
///
/// O leitor de tela recebe "3 horas e 24 minutos" em vez de "zero três agá
/// dois quatro", que é o que sairia de ler o formato compacto da tela.
String _spokenDuration(int minutes) {
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  final parts = <String>[
    if (hours > 0) '$hours ${hours == 1 ? 'hora' : 'horas'}',
    if (rest > 0 || hours == 0) '$rest ${rest == 1 ? 'minuto' : 'minutos'}',
  ];
  return parts.join(' e ');
}

String _phraseFor(WorkdayProgress progress) => switch (progress.phase) {
  WorkdayPhase.notStarted => 'Jornada ainda não iniciada',
  WorkdayPhase.working => 'Trabalhando',
  WorkdayPhase.onBreak => 'Em intervalo',
  WorkdayPhase.finished => 'Jornada concluída',
  WorkdayPhase.needsReview => 'Este dia precisa de revisão',
};

class _HeroReadout extends StatelessWidget {
  const _HeroReadout({required this.progress, required this.visual});

  final WorkdayProgress progress;
  final WorkdayVisual visual;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final since = progress.phaseSince;
    final goal = goalLine;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          minutesToCompactHm(progress.displayedMinutes),
          style: theme.textTheme.displayLarge,
        ),
        const SizedBox(height: HfSpace.sm),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(visual.icon, size: 17, color: visual.role.foreground),
            const SizedBox(width: HfSpace.xs + 2),
            Text(
              visual.label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: visual.role.foreground,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        if (since != null) ...[
          const SizedBox(height: HfSpace.xs),
          Text(
            progress.phase == WorkdayPhase.finished
                ? 'Encerrada às ${formatClock(since)}'
                : 'desde ${formatClock(since)}',
            style: theme.textTheme.bodySmall,
          ),
        ],
        if (goal != null) ...[
          const SizedBox(height: HfSpace.xs),
          Text(
            goal,
            style: theme.textTheme.bodySmall?.copyWith(
              color: progress.reachedGoal
                  ? context.hf.done.foreground
                  : theme.colorScheme.onSurfaceVariant,
              fontWeight: progress.reachedGoal
                  ? FontWeight.w600
                  : FontWeight.w400,
            ),
          ),
        ],
      ],
    );
  }

  /// Linha de meta, mostrada só quando há jornada configurada e o dia começou.
  ///
  /// Antes da primeira batida o "faltam 08h00" seria só a jornada inteira
  /// repetida — informação que o próprio contador zerado já dá.
  String? get goalLine {
    final remaining = progress.remainingMinutes;
    if (remaining == null || progress.phase == WorkdayPhase.notStarted) {
      return null;
    }
    if (remaining > 0) {
      return 'faltam ${minutesToCompactHm(remaining)} para a jornada';
    }
    if (remaining == 0) return 'jornada do dia cumprida';
    return '${minutesToCompactHm(-remaining)} além da jornada';
  }
}

/// Pinta o arco de jornada: quatro segmentos separados por folgas, sobre um
/// trilho neutro contínuo.
class _JourneyDialPainter extends CustomPainter {
  const _JourneyDialPainter({
    required this.value,
    required this.segments,
    required this.active,
    required this.track,
    required this.strokeWidth,
  });

  /// Progresso contínuo de 0 a [segments] — fracionário durante a animação.
  final double value;

  /// Quantas divisões o arco tem: quatro para os registros da jornada, uma
  /// para o progresso rumo à meta do dia.
  final int segments;

  final Color active;
  final Color track;
  final double strokeWidth;

  static const double _startAngle = math.pi * 0.75; // 135°, canto inferior esq.
  static const double _totalSweep = math.pi * 1.5; // 270°
  static const double _gap = 0.055; // radianos entre segmentos

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );
    final gaps = segments > 1 ? _gap * (segments - 1) : 0.0;
    final segmentSweep = (_totalSweep - gaps) / segments;

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth
      ..color = track;
    final activePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth
      ..color = active;

    for (var i = 0; i < segments; i++) {
      final start = _startAngle + i * (segmentSweep + _gap);
      canvas.drawArc(rect, start, segmentSweep, false, trackPaint);

      final fill = (value - i).clamp(0.0, 1.0);
      if (fill > 0) {
        canvas.drawArc(rect, start, segmentSweep * fill, false, activePaint);
      }
    }
  }

  @override
  bool shouldRepaint(_JourneyDialPainter old) =>
      old.value != value ||
      old.segments != segments ||
      old.active != active ||
      old.track != track ||
      old.strokeWidth != strokeWidth;
}
