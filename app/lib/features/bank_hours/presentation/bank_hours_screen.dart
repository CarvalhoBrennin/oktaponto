import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/hf_semantics.dart';
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
import '../../schedule/domain/work_schedule.dart';
import '../../schedule/presentation/schedule_provider.dart';
import '../../settings/presentation/settings_button.dart';

class BankHoursScreen extends ConsumerStatefulWidget {
  const BankHoursScreen({super.key});

  @override
  ConsumerState<BankHoursScreen> createState() => _BankHoursScreenState();
}

class _BankHoursScreenState extends ConsumerState<BankHoursScreen> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final now = ref.read(clockProvider).now();
    _month = DateTime(now.year, now.month);
  }

  void _move(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
  }

  Future<void> _openDay(DateTime date) =>
      showWorkDayEditor(context, ref, date);

  @override
  Widget build(BuildContext context) {
    final month = ref.watch(monthSummaryProvider(_month));
    final schedule = ref.watch(workScheduleProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Banco de horas'),
        actions: const [SettingsButton()],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(HfSpace.sm, 0, HfSpace.sm, 0),
            child: HfMonthSwitcher(month: _month, onChanged: _move),
          ),
          Expanded(
            child: month.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(horizontal: HfSpace.xl),
                child: Column(
                  children: [
                    SizedBox(height: HfSpace.xl),
                    HfSkeleton(height: 160, borderRadius: HfRadius.large),
                    SizedBox(height: HfSpace.huge),
                    HfSkeletonRow(),
                    HfSkeletonRow(),
                  ],
                ),
              ),
              error: (error, _) => Padding(
                padding: const EdgeInsets.all(HfSpace.xl),
                child: HfNotice(
                  tone: HfNoticeTone.error,
                  title: 'Não foi possível carregar o banco de horas',
                  message: friendlyError(error),
                ),
              ),
              data: (summary) => _BankHoursBody(
                month: _month,
                summary: summary,
                schedule: schedule,
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

class _BankHoursBody extends StatelessWidget {
  const _BankHoursBody({
    required this.month,
    required this.summary,
    required this.schedule,
    required this.onOpenDay,
    required this.onRefresh,
  });

  final DateTime month;
  final MonthSummary summary;
  final WorkSchedule? schedule;
  final Future<void> Function(DateTime date) onOpenDay;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (schedule == null) {
      return const _NoScheduleState();
    }
    if (!schedule!.isValid) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(HfSpace.xl),
        children: [
          HfNotice(
            tone: HfNoticeTone.error,
            title: 'Sua jornada precisa de ajuste',
            message: schedule!.problem!,
          ),
        ],
      );
    }

    final overtimeDays = summary.daysWithOvertime;
    final deficitDays = summary.daysWithDeficit;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          HfSpace.xl,
          HfSpace.lg,
          HfSpace.xl,
          HfSpace.section,
        ),
        children: [
          _BankHoursHeadline(month: month, summary: summary),
          if (summary.bankHoursDayCount == 0)
            const HfEmptyState(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Nenhum dia completo ainda',
              message:
                  'Complete as quatro batidas de um dia para começar a '
                  'movimentar o banco de horas.',
            )
          else ...[
            if (overtimeDays.isNotEmpty)
              HfSection(
                title: overtimeDays.length == 1
                    ? '1 dia com hora extra'
                    : '${overtimeDays.length} dias com horas extras',
                child: Column(
                  children: [
                    for (var index = 0; index < overtimeDays.length; index++)
                      _BankHoursDayRow(
                        day: overtimeDays[index],
                        onTap: () => onOpenDay(overtimeDays[index].date),
                        showBalance: false,
                        isLast: index == overtimeDays.length - 1,
                      ),
                  ],
                ),
              )
            else
              const HfEmptyState(
                icon: Icons.hourglass_empty_rounded,
                title: 'Nenhuma hora extra neste mês',
                message:
                    'As horas trabalhadas acima da sua jornada aparecem aqui '
                    'assim que um dia for concluído.',
              ),
            if (deficitDays.isNotEmpty)
              HfSection(
                title: 'Dias abaixo da meta',
                child: Column(
                  children: [
                    for (var index = 0; index < deficitDays.length; index++)
                      _BankHoursDayRow(
                        day: deficitDays[index],
                        onTap: () => onOpenDay(deficitDays[index].date),
                        showBalance: true,
                        isLast: index == deficitDays.length - 1,
                      ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _NoScheduleState extends StatelessWidget {
  const _NoScheduleState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        HfEmptyState(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Defina sua jornada',
          message:
              'O banco de horas compara suas batidas com a meta diária da '
              'jornada configurada.',
          action: OutlinedButton.icon(
            onPressed: () => openSettings(context),
            icon: const Icon(Icons.tune_rounded),
            label: const Text('Abrir configurações'),
          ),
        ),
      ],
    );
  }
}

class _BankHoursHeadline extends StatelessWidget {
  const _BankHoursHeadline({required this.month, required this.summary});

  final DateTime month;
  final MonthSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hf = context.hf;
    final balance = summary.bankBalanceMinutes;
    final balanceRole = balance < 0 ? hf.attention : hf.done;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          monthYearTitlePt(month).toUpperCase(),
          style: theme.textTheme.labelSmall,
        ),
        const SizedBox(height: HfSpace.sm),
        Text(
          signedMinutes(balance),
          style: theme.textTheme.displayLarge?.copyWith(
            color: balanceRole.foreground,
          ),
        ),
        const SizedBox(height: HfSpace.xs),
        const Text('Saldo do mês no banco de horas'),
        const SizedBox(height: HfSpace.lg),
        Row(
          children: [
            _BankMetric(
              icon: Icons.trending_up_rounded,
              role: hf.working,
              value: minutesToCompactHm(summary.overtimeMinutes),
              label: 'horas extras',
            ),
            const SizedBox(width: HfSpace.huge),
            _BankMetric(
              icon: Icons.event_available_outlined,
              role: hf.done,
              value: '${summary.bankHoursDayCount}',
              label: summary.bankHoursDayCount == 1
                  ? 'dia avaliado'
                  : 'dias avaliados',
            ),
          ],
        ),
      ],
    );
  }
}

class _BankMetric extends StatelessWidget {
  const _BankMetric({
    required this.icon,
    required this.role,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final HfRole role;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Flexible(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: role.foreground),
          const SizedBox(width: HfSpace.sm),
          Flexible(
            child: RichText(
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                style: theme.textTheme.bodyMedium,
                children: [
                  TextSpan(
                    text: value,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  TextSpan(text: ' $label'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BankHoursDayRow extends StatelessWidget {
  const _BankHoursDayRow({
    required this.day,
    required this.onTap,
    required this.showBalance,
    required this.isLast,
  });

  final WorkDaySummary day;
  final VoidCallback onTap;
  final bool showBalance;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hf = context.hf;
    final balance = day.balanceMinutes ?? 0;
    final role = balance < 0 ? hf.attention : hf.working;
    final amount = showBalance
        ? signedMinutes(balance)
        : signedMinutes(day.overtimeMinutes);
    final detail = '${minutesToCompactHm(day.workedMinutes)} trabalhadas · '
        '${minutesToCompactHm(day.targetMinutes ?? 0)} de meta';

    return Column(
      children: [
        Semantics(
          button: true,
          label: '${dayAndMonthPt(day.date)}, $amount, $detail',
          child: ExcludeSemantics(
            child: InkWell(
              onTap: onTap,
              borderRadius: HfRadius.small,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: HfSpace.md),
                child: Row(
                  children: [
                    SizedBox(
                      width: 46,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            day.date.day.toString().padLeft(2, '0'),
                            style: theme.textTheme.titleMedium,
                          ),
                          Text(
                            weekdayShortPt(day.date),
                            style: theme.textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: HfSpace.md),
                    Expanded(
                      child: Text(
                        detail,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    const SizedBox(width: HfSpace.md),
                    Text(
                      amount,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: role.foreground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (!isLast) const Divider(height: 1),
      ],
    );
  }
}

String signedMinutes(int minutes) {
  final sign = minutes > 0 ? '+' : minutes < 0 ? '-' : '';
  return '$sign${minutesToCompactHm(minutes.abs())}';
}
