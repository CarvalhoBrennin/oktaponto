import 'package:flutter/material.dart';

import '../design/hf_semantics.dart';
import '../design/hf_tokens.dart';

/// Tela/lista sem conteúdo: explica o que vai aparecer ali e, quando faz
/// sentido, oferece o primeiro passo.
class HfEmptyState extends StatelessWidget {
  const HfEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.schedule_outlined,
    this.action,
  });

  final String title;
  final String message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hf = context.hf;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: HfSpace.huge,
          vertical: HfSpace.giant,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: hf.idle.container,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: hf.idle.foreground, size: 26),
            ),
            const SizedBox(height: HfSpace.xl),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: HfSpace.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            if (action != null) ...[
              const SizedBox(height: HfSpace.xl),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Bloco cinza que segura o layout enquanto o dado chega.
///
/// Preferido a um spinner de tela cheia: mantém a página estável e evita a
/// impressão de que o app travou.
class HfSkeleton extends StatelessWidget {
  const HfSkeleton({
    super.key,
    this.height = 16,
    this.width,
    this.borderRadius = HfRadius.small,
  });

  final double height;
  final double? width;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: context.hf.track,
        borderRadius: borderRadius,
      ),
    );
  }
}

/// Esqueleto de uma linha de lista (título + metadado + valor).
class HfSkeletonRow extends StatelessWidget {
  const HfSkeletonRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: HfSpace.md),
      child: Row(
        children: [
          const HfSkeleton(height: 34, width: 34, borderRadius: HfRadius.small),
          const SizedBox(width: HfSpace.md),
          const Expanded(child: HfSkeleton(height: 12)),
          const SizedBox(width: HfSpace.giant),
          const HfSkeleton(height: 12, width: 52),
        ],
      ),
    );
  }
}
