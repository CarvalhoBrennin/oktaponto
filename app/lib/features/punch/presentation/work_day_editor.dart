import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/hf_semantics.dart';
import '../../../core/design/hf_tokens.dart';
import '../../../core/time/time_utils.dart';
import '../../../core/ui/hf_errors.dart';
import '../../../core/ui/hf_notice.dart';
import '../../../core/ui/hf_section.dart';
import '../../../core/ui/hf_sheet.dart';
import '../../../core/ui/hf_status_badge.dart';
import '../../../providers/app_providers.dart';
import '../../reminders/presentation/reminder_hooks.dart';
import '../domain/models.dart';
import '../domain/workday_progress.dart';
import 'workday_visuals.dart';

/// Abre o detalhe de um dia — leitura e correção no mesmo lugar.
///
/// Virou folha inferior (era um diálogo): o conteúdo é alto, tem campos de
/// texto e precisa conviver com o teclado sem virar uma caixa apertada no meio
/// da tela. O nome da função foi mantido porque é o ponto de entrada usado por
/// Hoje, Histórico e Fechamento.
Future<void> showWorkDayEditor(
  BuildContext context,
  WidgetRef ref,
  DateTime date,
) async {
  await showHfSheet<void>(
    context: context,
    builder: (_) => _WorkDaySheet(date: date),
  );
  ref.invalidate(daySummaryProvider(date));
  ref.invalidate(monthSummaryProvider(DateTime(date.year, date.month)));
}

class _WorkDaySheet extends ConsumerStatefulWidget {
  const _WorkDaySheet({required this.date});
  final DateTime date;

  @override
  ConsumerState<_WorkDaySheet> createState() => _WorkDaySheetState();
}

class _WorkDaySheetState extends ConsumerState<_WorkDaySheet> {
  late final TextEditingController _activity;
  late final TextEditingController _note;
  var _include = true;
  var _metadataLoaded = false;
  var _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _activity = TextEditingController();
    _note = TextEditingController();
    _loadMetadata();
  }

  @override
  void dispose() {
    _activity.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _loadMetadata() async {
    try {
      final metadata = await ref
          .read(workDayRepositoryProvider)
          .getDay(widget.date);
      if (!mounted) return;
      setState(() {
        _include = metadata.includeInTimesheet;
        _activity.text = metadata.activity ?? '';
        _note.text = metadata.note ?? '';
        _metadataLoaded = true;
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    }
  }

  void _invalidateDay() {
    ref.invalidate(daySummaryProvider(widget.date));
    ref.invalidate(
      monthSummaryProvider(DateTime(widget.date.year, widget.date.month)),
    );
    // Corrigir os horários de hoje muda quando o intervalo termina.
    unawaited(refreshBreakReminder(ref, widget.date));
  }

  Future<bool> _saveMetadata() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(workDayRepositoryProvider)
          .upsert(
            WorkDayMetadata(
              localDate: localDateKey(widget.date),
              includeInTimesheet: _include,
              activity: _activity.text.trim().isEmpty
                  ? null
                  : _activity.text.trim(),
              note: _note.text.trim().isEmpty ? null : _note.text.trim(),
            ),
          );
      _invalidateDay();
      if (mounted) setState(() => _error = null);
      return true;
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<TimeOfDay?> _pickTime(TimeOfDay initial, String helpText) {
    return showTimePicker(
      context: context,
      initialTime: initial,
      helpText: helpText,
      confirmText: 'Confirmar',
      cancelText: 'Cancelar',
    );
  }

  Future<void> _addPunch(PunchStep step) async {
    final picked = await _pickTime(TimeOfDay.now(), step.label.toUpperCase());
    if (picked == null) return;
    try {
      await ref
          .read(punchServiceProvider)
          .addManualPunch(
            widget.date,
            DateTime(
              widget.date.year,
              widget.date.month,
              widget.date.day,
              picked.hour,
              picked.minute,
            ),
          );
      _invalidateDay();
      if (mounted) setState(() => _error = null);
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    }
  }

  Future<void> _editPunch(Punch punch, PunchStep step) async {
    final local = punch.occurredAtLocal;
    final picked = await _pickTime(
      TimeOfDay(hour: local.hour, minute: local.minute),
      labelForPunchAt(step, punch).toUpperCase(),
    );
    if (picked == null) return;
    final editedLocal = DateTime(
      widget.date.year,
      widget.date.month,
      widget.date.day,
      picked.hour,
      picked.minute,
    );
    try {
      final editedOffsetMinutes = editedLocal.timeZoneOffset.inMinutes;
      await ref
          .read(punchServiceProvider)
          .editPunch(
            PunchEdit(
              id: punch.id,
              localDate: localDateKey(widget.date),
              occurredAtUtc: wallClockToUtc(editedLocal, editedOffsetMinutes),
              utcOffsetMinutes: editedOffsetMinutes,
              kind: punch.kind,
            ),
          );
      _invalidateDay();
      if (mounted) setState(() => _error = null);
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    }
  }

  Future<void> _deletePunch(Punch punch, PunchStep step) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Apagar este registro?'),
            content: Text(
              '${labelForPunchAt(step, punch)} às '
              '${formatClock(punch.occurredAtLocal)} será removida do dia. '
              'A alteração fica registrada na auditoria.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Apagar'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    try {
      await ref.read(punchServiceProvider).deletePunch(punch.id, widget.date);
      _invalidateDay();
      if (mounted) setState(() => _error = null);
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = widget.date;
    final summary = ref.watch(daySummaryProvider(date));

    return HfSheetScaffold(
      subtitle: weekdayPt(date),
      title: dayAndMonthPt(date),
      footer: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fechar'),
            ),
          ),
          const SizedBox(width: HfSpace.md),
          Expanded(
            child: FilledButton(
              onPressed: _metadataLoaded && !_saving
                  ? () async {
                      final saved = await _saveMetadata();
                      if (saved && context.mounted) Navigator.pop(context);
                    }
                  : null,
              child: Text(_saving ? 'Salvando...' : 'Salvar'),
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            HfNotice(tone: HfNoticeTone.error, message: _error!),
            const SizedBox(height: HfSpace.lg),
          ],
          summary.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: HfSpace.giant),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => HfNotice(
              tone: HfNoticeTone.error,
              message: friendlyError(error),
            ),
            data: (day) => _DayRecords(
              day: day,
              onAdd: _addPunch,
              onEdit: _editPunch,
              onDelete: _deletePunch,
            ),
          ),
          HfSection(
            title: 'Timesheet',
            top: HfSpace.huge,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _include,
                  onChanged: _metadataLoaded
                      ? (value) => setState(() => _include = value)
                      : null,
                  title: const Text('Incluir este dia no timesheet'),
                  subtitle: Text(
                    _include
                        ? 'Entra no total do mês.'
                        : 'Fica fora do arquivo gerado.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: HfSpace.lg),
                TextField(
                  controller: _activity,
                  enabled: _metadataLoaded,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Atividade do dia',
                    helperText: 'Opcional',
                  ),
                ),
                const SizedBox(height: HfSpace.lg),
                TextField(
                  controller: _note,
                  enabled: _metadataLoaded,
                  maxLines: 3,
                  minLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Observação',
                    helperText: 'Opcional',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Os quatro registros do dia, cada um com seu horário e suas correções.
class _DayRecords extends StatelessWidget {
  const _DayRecords({
    required this.day,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  final WorkDaySummary day;
  final void Function(PunchStep step) onAdd;
  final void Function(Punch punch, PunchStep step) onEdit;
  final void Function(Punch punch, PunchStep step) onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hf = context.hf;
    final steps = PunchStep.values;
    final visual = visualForDay(hf, day);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TOTAL DO DIA', style: theme.textTheme.labelSmall),
                  const SizedBox(height: HfSpace.xs),
                  Text(
                    minutesToCompactHm(day.workedMinutes),
                    style: theme.textTheme.displaySmall,
                  ),
                ],
              ),
            ),
            HfStatusBadge(
              role: visual.role,
              icon: visual.icon,
              label: visual.label,
            ),
          ],
        ),
        for (final issue in day.issues)
          Padding(
            padding: const EdgeInsets.only(top: HfSpace.md),
            child: HfNotice(
              tone: issue.blocking ? HfNoticeTone.attention : HfNoticeTone.info,
              message: issue.message,
            ),
          ),
        const SizedBox(height: HfSpace.xl),
        for (var index = 0; index < steps.length; index++)
          _RecordRow(
            step: steps[index],
            punch: index < day.punches.length ? day.punches[index] : null,
            // O domínio só aceita batidas em sequência: o próximo horário a
            // preencher é sempre o primeiro vazio.
            canAdd: index == day.punches.length,
            onAdd: () => onAdd(steps[index]),
            onEdit: (punch) => onEdit(punch, steps[index]),
            onDelete: (punch) => onDelete(punch, steps[index]),
          ),
        // Nenhum caminho do app cria uma quinta batida, mas se o banco tiver
        // uma (dado migrado, edição externa) ela precisa aparecer aqui — caso
        // contrário o dia fica inconsistente sem nenhuma forma de conserto.
        for (var index = steps.length; index < day.punches.length; index++)
          _RecordRow(
            step: PunchStep.exit,
            punch: day.punches[index],
            canAdd: false,
            extra: true,
            onAdd: () {},
            onEdit: (punch) => onEdit(punch, PunchStep.exit),
            onDelete: (punch) => onDelete(punch, PunchStep.exit),
          ),
      ],
    );
  }
}

class _RecordRow extends StatelessWidget {
  const _RecordRow({
    required this.step,
    required this.punch,
    required this.canAdd,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    this.extra = false,
  });

  final PunchStep step;
  final Punch? punch;
  final bool canAdd;

  /// Batida além das quatro previstas, mostrada só para poder ser apagada.
  final bool extra;

  final VoidCallback onAdd;
  final void Function(Punch punch) onEdit;
  final void Function(Punch punch) onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hf = context.hf;
    final registered = punch != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: HfSpace.sm),
      child: Row(
        children: [
          Icon(
            extra ? Icons.error_outline_rounded : iconForPunchAt(step, punch),
            size: 20,
            color: extra
                ? hf.attention.foreground
                : (registered ? hf.working.foreground : hf.idle.foreground),
          ),
          const SizedBox(width: HfSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  extra ? 'Registro extra' : labelForPunchAt(step, punch),
                  style: theme.textTheme.titleSmall,
                ),
                if (registered && punch!.isEdited)
                  Text('Corrigido', style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          if (registered)
            Text(
              formatClock(punch!.occurredAtLocal),
              style: theme.textTheme.titleMedium,
            )
          else
            Text('--:--', style: theme.textTheme.titleMedium),
          const SizedBox(width: HfSpace.sm),
          if (registered) ...[
            IconButton(
              tooltip: 'Ajustar horário',
              onPressed: () => onEdit(punch!),
              icon: const Icon(Icons.schedule_rounded, size: 20),
            ),
            IconButton(
              tooltip: 'Apagar registro',
              onPressed: () => onDelete(punch!),
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
            ),
          ] else
            IconButton(
              tooltip: canAdd
                  ? 'Informar horário'
                  : 'Preencha os registros anteriores primeiro',
              onPressed: canAdd ? onAdd : null,
              icon: const Icon(Icons.add_rounded, size: 20),
            ),
        ],
      ),
    );
  }
}
