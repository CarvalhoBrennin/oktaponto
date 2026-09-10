import 'package:flutter/material.dart';

import '../design/hf_semantics.dart';
import '../design/hf_tokens.dart';

/// Tom de uma mensagem contextual.
enum HfNoticeTone { attention, error, info, success }

/// Mensagem no lugar onde o problema acontece.
///
/// Substitui o SnackBar genérico: diz o que houve, onde houve e — quando
/// existe — oferece a ação que resolve.
class HfNotice extends StatelessWidget {
  const HfNotice({
    super.key,
    required this.message,
    this.tone = HfNoticeTone.attention,
    this.title,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final HfNoticeTone tone;
  final String? title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hf = context.hf;
    final (HfRole role, IconData icon) = switch (tone) {
      HfNoticeTone.attention => (hf.attention, Icons.error_outline_rounded),
      HfNoticeTone.error => (
        HfRole(
          foreground: theme.colorScheme.error,
          container: theme.colorScheme.errorContainer,
          onContainer: theme.colorScheme.onErrorContainer,
        ),
        Icons.report_gmailerrorred_rounded,
      ),
      HfNoticeTone.info => (hf.idle, Icons.info_outline_rounded),
      HfNoticeTone.success => (hf.done, Icons.check_circle_outline_rounded),
    };

    return Semantics(
      container: true,
      liveRegion: tone != HfNoticeTone.info,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(HfSpace.lg),
        decoration: BoxDecoration(
          color: role.container,
          borderRadius: HfRadius.medium,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: role.onContainer),
            const SizedBox(width: HfSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null) ...[
                    Text(
                      title!,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: role.onContainer,
                      ),
                    ),
                    const SizedBox(height: HfSpace.xs),
                  ],
                  Text(
                    message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: role.onContainer,
                    ),
                  ),
                  if (actionLabel != null && onAction != null) ...[
                    const SizedBox(height: HfSpace.sm),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: onAction,
                        style: TextButton.styleFrom(
                          foregroundColor: role.onContainer,
                          padding: const EdgeInsets.symmetric(
                            horizontal: HfSpace.md,
                          ),
                          minimumSize: const Size(0, 40),
                          tapTargetSize: MaterialTapTargetSize.padded,
                        ),
                        child: Text(actionLabel!),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
