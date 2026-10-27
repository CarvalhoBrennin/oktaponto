import 'dart:io';

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
import '../../punch/domain/workday_progress.dart';
import '../../punch/presentation/work_day_editor.dart';
import '../../schedule/domain/work_schedule.dart';
import '../../schedule/presentation/schedule_provider.dart';
import '../../settings/presentation/settings_button.dart';
import '../domain/overtime_report_exporter.dart';
import '../domain/overtime_report_signature.dart';

class BankHoursScreen extends ConsumerStatefulWidget {
  const BankHoursScreen({super.key});

  @override
  ConsumerState<BankHoursScreen> createState() => _BankHoursScreenState();
}

class _BankHoursScreenState extends ConsumerState<BankHoursScreen> {
  late DateTime _month;
  var _exportBusy = false;
  OvertimeReportGenerationResult? _lastExport;
  String? _lastExportSignature;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = ref.read(clockProvider).now();
    _month = DateTime(now.year, now.month);
  }

  void _move(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      _lastExport = null;
      _lastExportSignature = null;
      _error = null;
    });
  }

  Future<void> _openDay(DateTime date) => showWorkDayEditor(context, ref, date);

  Future<void> _export(MonthSummary month, WorkSchedule schedule) async {
    if (_exportBusy) return;
    setState(() {
      _exportBusy = true;
      _error = null;
    });
    try {
      final directory = await ref.read(fileServiceProvider).exportDirectory();
      final result = await ref
          .read(overtimeReportExporterProvider)
          .exportMonth(month, schedule, directory);
      if (!mounted) return;
      setState(() {
        _lastExport = result;
        _lastExportSignature = overtimeReportSourceSignature(month, schedule);
      });
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _exportBusy = false);
    }
  }

  Future<void> _shareCurrent() async {
    final export = _lastExport;
    final signature = _lastExportSignature;
    if (export == null || signature == null || _exportBusy) return;
    final selectedMonth = _month;
    setState(() {
      _exportBusy = true;
      _error = null;
    });
    try {
      final setup = await ref.read(scheduleSetupProvider.future);
      final schedule = setup.schedule;
      if (schedule == null || !schedule.isValid) {
        throw StateError('Defina uma jornada válida antes de compartilhar.');
      }
      final currentMonth = await ref.refresh(
        monthSummaryProvider(selectedMonth).future,
      );
      if (overtimeReportSourceSignature(currentMonth, schedule) != signature) {
        throw StateError(
          'As batidas ou a jornada mudaram desde a geração. Exporte o extrato '
          'novamente antes de compartilhar.',
        );
      }
      if (!await File(export.outputPath).exists()) {
        throw StateError(
          'O arquivo não existe mais. Gere o extrato novamente.',
        );
      }
      await ref
          .read(shareServiceProvider)
          .shareXlsx(
            export.outputPath,
            subject: 'Horas extras - ${export.monthYear}',
            text: 'Extrato de horas extras de ${export.monthYear}',
          );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = friendlyError(error);
        if (error is StateError) {
          _lastExport = null;
          _lastExportSignature = null;
        }
      });
    } finally {
      if (mounted) setState(() => _exportBusy = false);
    }
  }

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
              data: (summary) {
                final currentSignature = schedule == null
                    ? null
                    : overtimeReportSourceSignature(summary, schedule);
                final exportIsCurrent =
                    _lastExport != null &&
                    _lastExportSignature != null &&
                    currentSignature == _lastExportSignature;
                return _BankHoursBody(
                  month: _month,
                  summary: summary,
                  schedule: schedule,
                  busy: _exportBusy,
                  error: _error,
                  lastExport: exportIsCurrent ? _lastExport : null,
                  exportIsStale: _lastExport != null && !exportIsCurrent,
                  onExport: schedule == null
                      ? null
                      : () => _export(summary, schedule),
                  onShare: _shareCurrent,
                  onOpenDay: _openDay,
                  onRefresh: () => guardedRefresh(
                    () async =>
                        ref.refresh(monthSummaryProvider(_month).future),
                  ),
                );
              },
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
    required this.busy,
    required this.error,
    required this.lastExport,
    required this.exportIsStale,
    required this.onExport,
    required this.onShare,
    required this.onOpenDay,
    required this.onRefresh,
  });

  final DateTime month;
  final MonthSummary summary;
  final WorkSchedule? schedule;
  final bool busy;
  final String? error;
  final OvertimeReportGenerationResult? lastExport;
  final bool exportIsStale;
  final Future<void> Function()? onExport;
  final VoidCallback onShare;
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
    final hasBlockingIssues = summary.days.any(
      (day) => day.hasBlockingIssues || day.status == WorkDayStatus.invalid,
    );
    final pendingDays = summary.days
        .where(
          (day) =>
              day.punches.isNotEmpty &&
              !day.hasBlockingIssues &&
              day.status != WorkDayStatus.complete,
        )
        .length;

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
          if (error != null) ...[
            const SizedBox(height: HfSpace.lg),
            HfNotice(
              tone: HfNoticeTone.error,
              title: 'Não foi possível gerar o extrato',
              message: error!,
            ),
          ],
          if (exportIsStale) ...[
            const SizedBox(height: HfSpace.lg),
            const HfNotice(
              tone: HfNoticeTone.attention,
              title: 'O extrato ficou desatualizado',
              message: 'Gere um novo arquivo para incluir as mudanças do mês.',
            ),
          ],
          if (hasBlockingIssues) ...[
            const SizedBox(height: HfSpace.lg),
            const HfNotice(
              tone: HfNoticeTone.error,
              title: 'Revise as batidas antes de exportar',
              message:
                  'Há dias inconsistentes neste mês. Corrija-os no Histórico '
                  'para gerar um extrato confiável.',
            ),
          ],
          if (onExport != null) ...[
            const SizedBox(height: HfSpace.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: busy || hasBlockingIssues ? null : onExport,
                icon: busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.file_download_outlined),
                label: Text(
                  busy ? 'Gerando extrato…' : 'Exportar extrato Excel',
                ),
              ),
            ),
          ],
          if (pendingDays > 0) ...[
            const SizedBox(height: HfSpace.md),
            HfNotice(
              tone: HfNoticeTone.info,
              message:
                  '$pendingDays ${pendingDays == 1 ? 'dia incompleto fica' : 'dias incompletos ficam'} '
                  'fora do total exportado.',
            ),
          ],
          if (lastExport != null) ...[
            const SizedBox(height: HfSpace.lg),
            _OvertimeExportResult(
              export: lastExport!,
              busy: busy,
              onShare: onShare,
            ),
          ],
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

class _OvertimeExportResult extends StatelessWidget {
  const _OvertimeExportResult({
    required this.export,
    required this.busy,
    required this.onShare,
  });

  final OvertimeReportGenerationResult export;
  final bool busy;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final role = context.hf.done;
    final fileName = export.outputPath.split(Platform.pathSeparator).last;
    return Container(
      padding: const EdgeInsets.all(HfSpace.lg),
      decoration: BoxDecoration(
        color: role.container,
        borderRadius: HfRadius.medium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_outline_rounded, color: role.onContainer),
              const SizedBox(width: HfSpace.md),
              Expanded(
                child: Text(
                  'Extrato gerado',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: role.onContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: HfSpace.sm),
          Text(
            fileName,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: role.onContainer,
            ),
          ),
          Text(
            '${minutesToCompactHm(export.totalOvertimeMinutes)} · '
            '${export.overtimeDays} ${export.overtimeDays == 1 ? 'dia com extra' : 'dias com extra'}',
            style: theme.textTheme.bodySmall?.copyWith(color: role.onContainer),
          ),
          if (export.pendingDays > 0)
            Text(
              '${export.pendingDays} ${export.pendingDays == 1 ? 'dia pendente foi excluído' : 'dias pendentes foram excluídos'}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: role.onContainer,
              ),
            ),
          const SizedBox(height: HfSpace.lg),
          FilledButton.tonalIcon(
            onPressed: busy ? null : onShare,
            icon: const Icon(Icons.ios_share_rounded, size: 18),
            label: const Text('Compartilhar'),
          ),
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

class _BankHoursDayRow extends StatefulWidget {
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
  State<_BankHoursDayRow> createState() => _BankHoursDayRowState();
}

class _BankHoursDayRowState extends State<_BankHoursDayRow> {
  var _expanded = false;

  void _toggleExpanded() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hf = context.hf;
    final day = widget.day;
    final balance = day.balanceMinutes ?? 0;
    final role = balance < 0 ? hf.attention : hf.working;
    final amount = widget.showBalance
        ? signedMinutes(balance)
        : signedMinutes(day.overtimeMinutes);
    final detail =
        '${minutesToCompactHm(day.workedMinutes)} trabalhadas · '
        '${minutesToCompactHm(day.targetMinutes ?? 0)} de meta';

    return Column(
      children: [
        Semantics(
          button: true,
          expanded: _expanded,
          onTap: _toggleExpanded,
          hint: _expanded
              ? 'Toque para recolher os detalhes do dia.'
              : 'Toque para ver as batidas do dia.',
          label: '${dayAndMonthPt(day.date)}, $amount, $detail',
          child: ExcludeSemantics(
            child: InkWell(
              onTap: _toggleExpanded,
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
                      _expanded
                          ? Icons.expand_less_rounded
                          : Icons.chevron_right_rounded,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.only(
              left: 46 + HfSpace.md,
              right: HfSpace.xl,
              bottom: HfSpace.md,
            ),
            child: Container(
              padding: const EdgeInsets.all(HfSpace.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: HfRadius.small,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Batidas do dia', style: theme.textTheme.titleSmall),
                  const SizedBox(height: HfSpace.sm),
                  for (var index = 0; index < PunchStep.values.length; index++)
                    _OvertimeDetailLine(
                      label: PunchStep.values[index].label,
                      value: formatClock(day.punches[index].occurredAtLocal),
                    ),
                  const Divider(height: HfSpace.xl),
                  _OvertimeDetailLine(
                    label: 'Horas trabalhadas',
                    value: minutesToCompactHm(day.workedMinutes),
                  ),
                  _OvertimeDetailLine(
                    label: 'Meta diária',
                    value: minutesToCompactHm(day.targetMinutes ?? 0),
                  ),
                  _OvertimeDetailLine(
                    label: widget.showBalance ? 'Saldo do dia' : 'Horas extras',
                    value: widget.showBalance
                        ? signedMinutes(balance)
                        : signedMinutes(day.overtimeMinutes),
                    emphasize: true,
                  ),
                  const SizedBox(height: HfSpace.sm),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: widget.onTap,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Editar batidas'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (!widget.isLast) const Divider(height: 1),
      ],
    );
  }
}

class _OvertimeDetailLine extends StatelessWidget {
  const _OvertimeDetailLine({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = emphasize
        ? theme.textTheme.titleSmall
        : theme.textTheme.bodySmall;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: HfSpace.xs),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style?.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

String signedMinutes(int minutes) {
  final sign = minutes > 0
      ? '+'
      : minutes < 0
      ? '-'
      : '';
  return '$sign${minutesToCompactHm(minutes.abs())}';
}
