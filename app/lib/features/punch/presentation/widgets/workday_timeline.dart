import 'package:flutter/material.dart';

import '../../../../core/design/hf_semantics.dart';
import '../../../../core/design/hf_tokens.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/time/time_utils.dart';
import '../../domain/models.dart';
import '../../domain/workday_progress.dart';
import '../workday_visuals.dart';

/// A jornada como uma linha, não como quatro cartões soltos.
///
/// Um trilho vertical liga os quatro registros na ordem em que acontecem.
/// Ponto cheio = registrado; anel destacado = próximo passo; ponto vazio =
/// ainda vai acontecer. O trilho entre dois pontos assume a cor do período que
/// os separa, então o intervalo aparece em âmbar e os períodos de trabalho na
/// cor de trabalho — a forma conta a história do dia sem legenda.
class WorkdayTimeline extends StatelessWidget {
  const WorkdayTimeline({
    super.key,
    required this.punches,
    required this.progress,
    this.onEdit,
  });

  final List<Punch> punches;
  final WorkdayProgress progress;

  /// Chamado ao tocar um registro existente. `null` deixa a timeline apenas
  /// informativa (é o caso dentro da folha de detalhe, que já edita ali).
  final void Function(Punch punch)? onEdit;

  @override
  Widget build(BuildContext context) {
    final hf = context.hf;
    final steps = PunchStep.values;

    // Os três períodos entre as quatro batidas: trabalho, intervalo, trabalho.
    // A cor pertence ao período, não à batida — o ponto diz se o registro
    // existe, o trecho diz que tipo de tempo separa um registro do seguinte.
    final periods = <Color>[
      hf.working.foreground,
      hf.resting.foreground,
      hf.working.foreground,
    ];

    // Cada linha pinta metade do conector acima e metade do de baixo. As duas
    // metades precisam receber a mesma cor e o mesmo estado, senão o trecho
    // entre dois pontos aparece cortado ao meio.
    Color colorOf(int period) => periods[period];
    bool isDrawn(int period) => punches.length > period;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < steps.length; index++)
          _TimelineRow(
            step: steps[index],
            punch: index < punches.length ? punches[index] : null,
            isNext: progress.nextStep == steps[index],
            // Trecho acima: o período que termina nesta batida.
            topColor: index == 0 ? null : colorOf(index - 1),
            topActive: index > 0 && isDrawn(index - 1),
            // Trecho abaixo: o período que começa nesta batida.
            bottomColor: index == steps.length - 1 ? null : colorOf(index),
            bottomActive: index < steps.length - 1 && isDrawn(index),
            onTap: onEdit,
          ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.step,
    required this.punch,
    required this.isNext,
    required this.topColor,
    required this.topActive,
    required this.bottomColor,
    required this.bottomActive,
    required this.onTap,
  });

  final PunchStep step;
  final Punch? punch;
  final bool isNext;

  /// Cor do período acima desta batida; `null` na primeira linha.
  final Color? topColor;
  final bool topActive;

  /// Cor do período abaixo desta batida; `null` na última linha.
  final Color? bottomColor;
  final bool bottomActive;

  final void Function(Punch punch)? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hf = context.hf;
    final registered = punch != null;
    // O ponto responde só uma pergunta: este registro existe? Que tipo de
    // período ele inicia é assunto do trecho, não do marcador.
    final role = registered || isNext ? hf.working : hf.idle;

    final label = Text(
      labelForPunchAt(step, punch),
      style:
          (registered || isNext
                  ? theme.textTheme.titleSmall
                  : theme.textTheme.bodyLarge)
              ?.copyWith(
                color: registered || isNext
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurfaceVariant,
              ),
    );

    final time = Text(
      registered ? formatClock(punch!.occurredAtLocal) : '--:--',
      style: theme.textTheme.titleMedium?.copyWith(
        color: registered
            ? theme.colorScheme.onSurface
            : theme.colorScheme.onSurfaceVariant,
        fontFeatures: AppTheme.tabularFigures,
      ),
    );

    final row = IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 32,
            child: CustomPaint(
              painter: _RailPainter(
                dotColor: role.foreground,
                trackColor: hf.track,
                filled: registered,
                emphasized: isNext,
                // Um trecho acende assim que o período começa: durante o
                // expediente ele mostra onde o usuário está agora.
                topColor: topActive ? topColor : null,
                hasTop: topColor != null,
                bottomColor: bottomActive ? bottomColor : null,
                hasBottom: bottomColor != null,
              ),
            ),
          ),
          const SizedBox(width: HfSpace.md),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: HfSpace.lg),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        label,
                        if (isNext && !registered) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Próximo registro',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: hf.working.foreground,
                            ),
                          ),
                        ] else if (registered && punch!.isEdited) ...[
                          const SizedBox(height: 2),
                          Text('Corrigido', style: theme.textTheme.bodySmall),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: HfSpace.md),
                  time,
                  if (registered && onTap != null) ...[
                    const SizedBox(width: HfSpace.sm),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );

    final semanticLabel = labelForPunchAt(step, punch);
    final semanticValue = registered
        ? '${formatClock(punch!.occurredAtLocal)}'
              '${punch!.isEdited ? ', corrigido' : ''}'
        : (isNext ? 'não registrado, próximo passo' : 'não registrado');

    if (!registered || onTap == null) {
      return Semantics(
        label: semanticLabel,
        value: semanticValue,
        container: true,
        child: ExcludeSemantics(child: row),
      );
    }

    return Semantics(
      label: semanticLabel,
      value: semanticValue,
      button: true,
      hint: 'Toque para corrigir',
      container: true,
      child: ExcludeSemantics(
        child: InkWell(
          borderRadius: HfRadius.small,
          onTap: () => onTap!(punch!),
          child: row,
        ),
      ),
    );
  }
}

/// Desenha o trilho vertical e o marcador de um registro.
///
/// Cada linha da timeline pinta a metade de baixo do conector que a liga à
/// linha seguinte e a metade de cima do que a liga à anterior. As duas metades
/// de um mesmo conector recebem a mesma cor, senão o trecho entre dois pontos
/// aparece partido ao meio.
class _RailPainter extends CustomPainter {
  const _RailPainter({
    required this.dotColor,
    required this.trackColor,
    required this.filled,
    required this.emphasized,
    required this.hasTop,
    required this.topColor,
    required this.hasBottom,
    required this.bottomColor,
  });

  final Color dotColor;
  final Color trackColor;
  final bool filled;
  final bool emphasized;

  /// Existe conector nesta direção (falso nas pontas da timeline).
  final bool hasTop;
  final bool hasBottom;

  /// Cor do período correspondente, ou `null` enquanto ele não começou —
  /// nesse caso o trecho é desenhado no trilho neutro.
  final Color? topColor;
  final Color? bottomColor;

  static const double _radius = 6;

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final line = Paint()
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    if (hasTop) {
      line.color = topColor ?? trackColor;
      canvas.drawLine(
        Offset(centerX, 0),
        Offset(centerX, centerY - _radius - 4),
        line,
      );
    }
    if (hasBottom) {
      line.color = bottomColor ?? trackColor;
      canvas.drawLine(
        Offset(centerX, centerY + _radius + 4),
        Offset(centerX, size.height),
        line,
      );
    }

    final center = Offset(centerX, centerY);
    if (emphasized && !filled) {
      // Halo suave: o próximo passo é o único ponto que ganha peso extra.
      canvas.drawCircle(
        center,
        _radius + 5,
        Paint()..color = dotColor.withValues(alpha: 0.18),
      );
    }
    if (filled) {
      canvas.drawCircle(center, _radius, Paint()..color = dotColor);
    } else {
      canvas.drawCircle(
        center,
        _radius - 1,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = emphasized ? dotColor : trackColor,
      );
    }
  }

  @override
  bool shouldRepaint(_RailPainter old) =>
      old.hasTop != hasTop ||
      old.hasBottom != hasBottom ||
      old.topColor != topColor ||
      old.dotColor != dotColor ||
      old.trackColor != trackColor ||
      old.filled != filled ||
      old.emphasized != emphasized ||
      old.bottomColor != bottomColor;
}
