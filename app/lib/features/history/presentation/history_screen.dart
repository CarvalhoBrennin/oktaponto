import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/hf_tokens.dart';
import '../../../core/time/time_utils.dart';
import '../../../core/ui/hf_errors.dart';
import '../../../core/ui/hf_month_switcher.dart';
import '../../../core/ui/hf_notice.dart';
import '../../../core/ui/hf_section.dart';
import '../../../core/ui/hf_states.dart';
import '../../../providers/app_providers.dart';
import '../../punch/domain/models.dart';
import '../../punch/presentation/work_day_editor.dart';
import '../../settings/presentation/settings_button.dart';
import 'widgets/day_history_row.dart';
import 'widgets/month_calendar.dart';

/// Histórico — o mês inteiro primeiro, o dia depois.
///
/// Calendário e lista convivem na mesma rolagem em vez de um seletor de modo:
/// o calendário responde "como foi o mês" e a lista responde "quanto em cada
/// dia". Um alternador obrigaria o usuário a escolher antes de saber o que
/// está procurando.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  late DateTime _month;
  late DateTime _today;

  @override
  void initState() {
    super.initState();
    _today = dateOnly(ref.read(clockProvider).now());
    _month = DateTime(_today.year, _today.month);
  }

  void _move(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      // Reavalia "hoje" a cada navegação: o app pode ficar aberto além da
      // meia-noite e o destaque do calendário não pode envelhecer.
      _today = dateOnly(ref.read(clockProvider).now());
    });
  }

  Future<void> _openDay(DateTime date) => showWorkDayEditor(context, ref, date);

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(monthSummaryProvider(_month));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Histórico'),
        actions: const [SettingsButton()],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(HfSpace.sm, 0, HfSpace.sm, 0),
            child: HfMonthSwitcher(month: _month, onChanged: _move),
          ),
          Expanded(
            child: summary.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(horizontal: HfSpace.xl),
                child: Column(
                  children: [
                    SizedBox(height: HfSpace.xl),
                    HfSkeleton(height: 220, borderRadius: HfRadius.large),
                    SizedBox(height: HfSpace.huge),
                    HfSkeletonRow(),
                    HfSkeletonRow(),
                    HfSkeletonRow(),
                  ],
                ),
              ),
              error: (error, _) => Padding(
                padding: const EdgeInsets.all(HfSpace.xl),
                child: HfNotice(
                  tone: HfNoticeTone.error,
                  title: 'Não foi possível carregar o mês',
                  message: friendlyError(error),
                ),
              ),
              data: (month) => _MonthBody(
                month: _month,
                today: _today,
                summary: month,
                onOpenDay: _openDay,
                onRefresh: () => guardedRefresh(
                  () async => ref.refresh(monthSummaryProvider(_month).future),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthBody extends StatelessWidget {
  const _MonthBody({
    required this.month,
    required this.today,
    required this.summary,
    required this.onOpenDay,
    required this.onRefresh,
  });

  final DateTime month;
  final DateTime today;
  final MonthSummary summary;
  final Future<void> Function(DateTime date) onOpenDay;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final byDay = <int, WorkDaySummary>{
      for (final day in summary.days) day.date.day: day,
    };
    final registered = summary.days
        .where((day) => day.punches.isNotEmpty)
        .toList();
    final needsReview = registered
        .where(
          (day) =>
              day.status != WorkDayStatus.complete || day.hasBlockingIssues,
        )
        .length;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          HfSpace.xl,
          HfSpace.md,
          HfSpace.xl,
          HfSpace.section,
        ),
        children: [
          MonthCalendar(
            month: month,
            days: byDay,
            today: today,
            onSelect: onOpenDay,
          ),
          if (registered.isEmpty)
            HfEmptyState(
              icon: Icons.event_available_outlined,
              title: 'Nenhum registro neste mês',
              message:
                  'Quando você registrar uma jornada, ela aparece aqui — com '
                  'horários, total e o que ainda precisa de ajuste.',
              action: OutlinedButton.icon(
                onPressed: () => onOpenDay(DateTime(month.year, month.month)),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Lançar um dia'),
              ),
            )
          else ...[
            HfSection(
              title:
                  '${registered.length} '
                  '${registered.length == 1 ? 'dia registrado' : 'dias registrados'}',
              trailing: needsReview > 0
                  ? Text(
                      '$needsReview a revisar',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    )
                  : null,
              child: Column(
                children: [
                  for (var i = 0; i < registered.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    DayHistoryRow(
                      day: registered[i],
                      onTap: () => onOpenDay(registered[i].date),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
