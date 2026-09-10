import 'package:flutter/material.dart';

import '../../../../core/design/hf_semantics.dart';
import '../../../../core/design/hf_tokens.dart';
import '../../domain/workday_progress.dart';
import '../workday_visuals.dart';

/// A ação principal da jornada.
///
/// Uma única ação por contexto: o rótulo é sempre o próximo passo real do dia,
/// e a transição entre um passo e o seguinte é animada para que registrar um
/// ponto pareça um movimento contínuo, e não uma tela que piscou.
class PunchButton extends StatelessWidget {
  const PunchButton({
    super.key,
    required this.progress,
    required this.onPressed,
    required this.busy,
  });

  final WorkdayProgress progress;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final next = progress.nextStep;

    if (progress.phase == WorkdayPhase.finished) {
      return const _StaticState(
        icon: Icons.check_circle_rounded,
        label: 'Jornada concluída',
        role: _StateRole.done,
      );
    }
    // Sem próximo passo e sem jornada concluída só sobra o dia inconsistente
    // (por exemplo, depois de apagar a entrada e restar uma saída solta).
    // Registrar aqui é impossível, e o caminho de saída é a correção.
    if (next == null) {
      return const _StaticState(
        icon: Icons.priority_high_rounded,
        label: 'Corrija o dia para continuar',
        role: _StateRole.attention,
      );
    }

    final enabled = onPressed != null && !busy;
    final label = next.actionLabel;

    return SizedBox(
      height: HfSize.primaryAction,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: label,
        child: ExcludeSemantics(
          child: FilledButton(
            onPressed: enabled ? onPressed : null,
            style: FilledButton.styleFrom(
              shape: const RoundedRectangleBorder(borderRadius: HfRadius.large),
              padding: const EdgeInsets.symmetric(horizontal: HfSpace.xxl),
              textStyle: theme.textTheme.titleMedium,
            ),
            child: AnimatedSwitcher(
              duration: HfMotion.base,
              switchInCurve: HfMotion.enter,
              switchOutCurve: HfMotion.exit,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.28),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: Row(
                key: ValueKey<String>(busy ? 'busy' : label),
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (busy)
                    SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: theme.colorScheme.onPrimary,
                      ),
                    )
                  else
                    Icon(iconForStep(next), size: 20),
                  const SizedBox(width: HfSpace.md),
                  Flexible(
                    child: Text(
                      busy ? 'Registrando...' : label,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _StateRole { done, attention }

/// Ocupa o lugar do CTA quando não há ação a oferecer: jornada encerrada ou
/// dia inconsistente. É um estado, não um botão desabilitado.
///
/// Sem confete e sem gamificação — a sensação buscada é a de uma tarefa
/// arrumada e encerrada.
class _StaticState extends StatelessWidget {
  const _StaticState({
    required this.icon,
    required this.label,
    required this.role,
  });

  final IconData icon;
  final String label;
  final _StateRole role;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hf = context.hf;
    final HfRole colors = switch (role) {
      _StateRole.done => hf.done,
      _StateRole.attention => hf.attention,
    };

    return Semantics(
      container: true,
      label: label,
      child: ExcludeSemantics(
        child: Container(
          height: HfSize.primaryAction,
          padding: const EdgeInsets.symmetric(horizontal: HfSpace.lg),
          decoration: BoxDecoration(
            color: colors.container,
            borderRadius: HfRadius.large,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TweenAnimationBuilder<double>(
                duration: HfMotion.slow,
                curve: HfMotion.enter,
                tween: Tween<double>(begin: 0.6, end: 1),
                builder: (context, value, child) =>
                    Transform.scale(scale: value, child: child),
                child: Icon(icon, size: 22, color: colors.onContainer),
              ),
              const SizedBox(width: HfSpace.md),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colors.onContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
