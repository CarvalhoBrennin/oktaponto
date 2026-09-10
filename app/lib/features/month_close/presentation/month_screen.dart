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
import '../../punch/presentation/work_day_editor.dart';
import '../../settings/presentation/settings_button.dart';
import '../../timesheet/domain/timesheet_source_signature.dart';
import '../domain/weekly_distribution.dart';
import 'widgets/month_headline.dart';
import 'widgets/weekly_hours_chart.dart';

/// Fechamento — o mês resumido e, quando ele fecha, o arquivo.
///
/// A ordem responde às perguntas na sequência em que elas aparecem: quanto
/// trabalhei, o que ainda falta e só então gerar. A regra de bloqueio continua
/// sendo a do `MonthlyCloseValidator`; a tela só passou a mostrar cada
/// pendência ao lado do dia que a causou.
class MonthScreen extends ConsumerStatefulWidget {
  const MonthScreen({super.key});

  @override
  ConsumerState<MonthScreen> createState() => _MonthScreenState();
}

class _MonthScreenState extends ConsumerState<MonthScreen> {
  late DateTime _month;
  var _busy = false;
  TimesheetGenerationResult? _lastExport;
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

  Future<void> _export(MonthSummary month) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final profile = await ref.read(settingsRepositoryProvider).getProfile();
      final directory = await ref.read(fileServiceProvider).exportDirectory();
      final result = await ref
          .read(timesheetExporterProvider)
          .exportMonth(month, profile, directory);
      if (!mounted) return;
      setState(() {
        _lastExport = result;
        _lastExportSignature = timesheetSourceSignature(month, profile);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _shareCurrent() async {
    final export = _lastExport;
    final signature = _lastExportSignature;
    if (export == null || signature == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final currentMonth = await ref.refresh(
        monthSummaryProvider(_month).future,
      );
      final profile = await ref.read(settingsRepositoryProvider).getProfile();
      final currentSignature = timesheetSourceSignature(currentMonth, profile);
      if (currentSignature != signature) {
        throw StateError(
          'Os dados mudaram desde a última geração. Gere o timesheet '
          'novamente antes de compartilhar.',
        );
      }
      if (!await File(export.outputPath).exists()) {
        throw StateError(
          'O arquivo exportado não existe mais. Gere o timesheet novamente.',
        );
      }
      await ref
          .read(shareServiceProvider)
          .shareXlsx(export.outputPath, monthYear: export.monthYear);
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
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncMonth = ref.watch(monthSummaryProvider(_month));
    final asyncProfile = ref.watch(profileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fechamento'),
        actions: const [SettingsButton()],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(HfSpace.sm, 0, HfSpace.sm, 0),
            child: HfMonthSwitcher(month: _month, onChanged: _move),
          ),
          Expanded(
            child: asyncMonth.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(horizontal: HfSpace.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: HfSpace.xl),
                    HfSkeleton(height: 54, width: 190),
                    SizedBox(height: HfSpace.xl),
                    HfSkeleton(height: 14, width: 240),
                    SizedBox(height: HfSpace.giant),
                    HfSkeleton(height: 60, borderRadius: HfRadius.large),
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
              data: (month) {
                final validation = ref
                    .watch(monthlyValidatorProvider)
                    .validate(month);
                final currentProfile = asyncProfile.asData?.value;
                final exportIsCurrent =
                    _lastExport != null &&
                    _lastExportSignature != null &&
                    currentProfile != null &&
                    timesheetSourceSignature(month, currentProfile) ==
                        _lastExportSignature;
                return _MonthCloseBody(
                  month: _month,
                  summary: month,
                  validation: validation,
                  busy: _busy,
                  error: _error,
                  lastExport: exportIsCurrent ? _lastExport : null,
                  exportIsStale: _lastExport != null && !exportIsCurrent,
                  onExport: () => _export(month),
                  onShare: _shareCurrent,
                  onOpenDay: (date) => showWorkDayEditor(context, ref, date),
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

class _MonthCloseBody extends StatelessWidget {
  const _MonthCloseBody({
    required this.month,
    required this.summary,
    required this.validation,
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
  final MonthValidationResult validation;
  final bool busy;
  final String? error;
  final TimesheetGenerationResult? lastExport;
  final bool exportIsStale;
  final VoidCallback onExport;
  final VoidCallback onShare;
  final Future<void> Function(DateTime date) onOpenDay;
  final Future<void> Function() onRefresh;

  /// Dias incluídos no timesheet que ainda não fecham.
  ///
  /// Deriva das mesmas condições que o validador usa para bloquear a
  /// exportação, só que agrupadas por dia — para que a pendência apareça onde
  /// o usuário pode resolvê-la.
  List<WorkDaySummary> get _pendingDays => summary.days
      .where(
        (day) =>
            day.includeInTimesheet &&
            (day.status != WorkDayStatus.complete ||
                day.hasBlockingIssues ||
                day.workedMinutes <= 0),
      )
      .toList();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final included = summary.days.where((d) => d.includeInTimesheet).length;
    final pending = _pendingDays;
    final weeks = weeklyDistribution(summary);
    final pendingReasons = {for (final day in pending) _reasonFor(day)};
    final hasAnyRecord = summary.days.any((day) => day.punches.isNotEmpty);

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
          if (!hasAnyRecord)
            const HfEmptyState(
              icon: Icons.description_outlined,
              title: 'Nada para fechar ainda',
              message:
                  'Este mês ainda não tem jornadas registradas. Assim que '
                  'houver, o resumo e a geração do timesheet aparecem aqui.',
            )
          else ...[
            MonthHeadline(
              month: month,
              totalMinutes: summary.totalMinutes,
              includedDays: included,
              pendingCount: pending.length,
            ),
            if (weeks.length > 1)
              HfSection(
                title: 'Distribuição por semana',
                child: WeeklyHoursChart(weeks: weeks),
              ),
            if (pending.isNotEmpty)
              HfSection(
                title: pending.length == 1
                    ? '1 dia precisa de atenção'
                    : '${pending.length} dias precisam de atenção',
                child: Column(
                  children: [
                    for (final day in pending)
                      _PendingDayTile(
                        day: day,
                        onTap: () => onOpenDay(day.date),
                      ),
                  ],
                ),
              ),
            // Pendências que nenhum cartão de dia cobre — mês vazio, data
            // duplicada, divergência num dia que aparenta estar completo.
            for (final issue in validation.issues.where(
              (issue) =>
                  issue.blocking &&
                  !_isCoveredByATile(issue, pending, pendingReasons),
            ))
              Padding(
                padding: const EdgeInsets.only(top: HfSpace.md),
                child: HfNotice(message: issue.message),
              ),
            HfSection(
              title: 'Timesheet',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    validation.isValid
                        ? 'Tudo pronto para fechar o mês.'
                        : pending.isEmpty
                        ? 'Resolva as pendências acima para liberar a geração.'
                        : pending.length == 1
                        ? 'Um registro precisa de ajuste antes do fechamento.'
                        : '${pending.length} registros precisam de ajuste '
                              'antes do fechamento.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  if (error != null) ...[
                    const SizedBox(height: HfSpace.md),
                    HfNotice(tone: HfNoticeTone.error, message: error!),
                  ],
                  const SizedBox(height: HfSpace.lg),
                  SizedBox(
                    height: HfSize.primaryAction,
                    child: FilledButton.icon(
                      onPressed: validation.isValid && !busy ? onExport : null,
                      style: FilledButton.styleFrom(
                        shape: const RoundedRectangleBorder(
                          borderRadius: HfRadius.large,
                        ),
                        textStyle: theme.textTheme.titleMedium,
                      ),
                      icon: busy
                          ? SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: theme.colorScheme.onPrimary,
                              ),
                            )
                          : const Icon(Icons.description_outlined, size: 20),
                      label: Text(busy ? 'Gerando...' : 'Gerar timesheet'),
                    ),
                  ),
                  if (exportIsStale) ...[
                    const SizedBox(height: HfSpace.md),
                    const HfNotice(
                      tone: HfNoticeTone.info,
                      message:
                          'Os dados mudaram depois da última geração. Gere o '
                          'arquivo de novo para compartilhar a versão atual.',
                    ),
                  ],
                  if (lastExport != null) ...[
                    const SizedBox(height: HfSpace.lg),
                    _ExportResult(
                      export: lastExport!,
                      busy: busy,
                      onShare: onShare,
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

  /// Uma pendência já está coberta quando o cartão de um dia a exibe.
  ///
  /// Dois caminhos, porque o validador emite dois tipos de código: os que
  /// carregam a data no nome (`incomplete_2026-09-03`) e os que vêm crus do
  /// validador de sequência (`invalid_kind_0`) e só aparecem como mensagem.
  /// Filtrar apenas pelo sufixo de data mostraria mensagens duplicadas e, pior,
  /// esconderia `derived_mismatch_<data>` de um dia completo — que não tem
  /// cartão nenhum e deixaria a exportação bloqueada sem explicação.
  bool _isCoveredByATile(
    ValidationIssue issue,
    List<WorkDaySummary> pending,
    Set<String> reasons,
  ) {
    if (reasons.contains(issue.message)) return true;
    return pending.any((day) => issue.code.endsWith(localDateKey(day.date)));
  }
}

/// Diz o que está faltando naquele dia, em vez de repetir "dia inválido".
///
/// Fica no topo do arquivo porque o corpo da tela também precisa dela: é assim
/// que ele sabe quais pendências do validador já estão sendo exibidas.
String _reasonFor(WorkDaySummary day) {
  final blocking = day.issues.where((issue) => issue.blocking);
  if (blocking.isNotEmpty) return blocking.first.message;
  // O que está faltando vem antes do total zerado: um dia com uma única
  // batida também tem zero minutos, e "faltam três horários" é bem mais
  // acionável do que "não tem horas registradas".
  return switch (day.punches.length) {
    0 => 'Nenhum horário registrado neste dia.',
    1 => 'Falta a saída para o intervalo, o retorno e a saída final.',
    2 => 'Falta o retorno do intervalo e a saída final.',
    3 => 'Falta a saída final.',
    _ when day.workedMinutes <= 0 =>
      'Os quatro horários estão registrados, mas o total do dia ficou zerado.',
    _ => 'Este dia precisa de revisão antes do fechamento.',
  };
}

class _PendingDayTile extends StatelessWidget {
  const _PendingDayTile({required this.day, required this.onTap});

  final WorkDaySummary day;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hf = context.hf;

    return Padding(
      padding: const EdgeInsets.only(bottom: HfSpace.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: HfRadius.medium,
        child: Container(
          padding: const EdgeInsets.all(HfSpace.lg),
          decoration: BoxDecoration(
            color: hf.attention.container,
            borderRadius: HfRadius.medium,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.priority_high_rounded,
                size: 20,
                color: hf.attention.onContainer,
              ),
              const SizedBox(width: HfSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${weekdayPt(day.date)}, ${dayAndMonthPt(day.date)}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: hf.attention.onContainer,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _reasonFor(day),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: hf.attention.onContainer,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: HfSpace.sm),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: hf.attention.onContainer,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExportResult extends StatelessWidget {
  const _ExportResult({
    required this.export,
    required this.busy,
    required this.onShare,
  });

  final TimesheetGenerationResult export;
  final bool busy;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hf = context.hf;
    final fileName = export.outputPath.split(Platform.pathSeparator).last;

    return Container(
      padding: const EdgeInsets.all(HfSpace.lg),
      decoration: BoxDecoration(
        color: hf.done.container,
        borderRadius: HfRadius.medium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.check_circle_outline_rounded,
                size: 20,
                color: hf.done.onContainer,
              ),
              const SizedBox(width: HfSpace.md),
              Expanded(
                child: Text(
                  'Arquivo gerado',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: hf.done.onContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: HfSpace.sm),
          Text(
            fileName,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: hf.done.onContainer,
            ),
          ),
          Text(
            '${export.includedDays} '
            '${export.includedDays == 1 ? 'dia' : 'dias'} · '
            '${minutesToCompactHm(export.totalMinutes)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: hf.done.onContainer,
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
