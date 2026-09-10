import 'package:flutter/material.dart';

import '../../../../core/design/hf_tokens.dart';

/// Um grupo de ajustes: título, descrição curta e o conteúdo.
///
/// Sem cartões aninhados — o agrupamento vem do espaço e da sobrelinha.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({
    super.key,
    required this.title,
    required this.children,
    this.description,
    this.trailing,
    this.first = false,
  });

  final String title;
  final String? description;
  final List<Widget> children;
  final Widget? trailing;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!first) ...[
          const SizedBox(height: HfSpace.huge),
          Divider(color: theme.colorScheme.outlineVariant),
          const SizedBox(height: HfSpace.huge),
        ],
        Row(
          children: [
            Expanded(
              child: Text(
                title.toUpperCase(),
                style: theme.textTheme.labelSmall,
              ),
            ),
            ?trailing,
          ],
        ),
        if (description != null) ...[
          const SizedBox(height: HfSpace.sm),
          Text(description!, style: theme.textTheme.bodyMedium),
        ],
        const SizedBox(height: HfSpace.lg),
        ...children,
      ],
    );
  }
}
