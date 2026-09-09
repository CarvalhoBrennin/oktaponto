import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/time_utils.dart';
import '../../../providers/app_providers.dart';
import '../domain/models.dart';

Future<void> showWorkDayEditor(
  BuildContext context,
  WidgetRef ref,
  DateTime date,
) async {
  await showDialog<void>(
    context: context,
    builder: (_) => _WorkDayEditorDialog(date: date),
  );
  ref.invalidate(daySummaryProvider(date));
  ref.invalidate(monthSummaryProvider(DateTime(date.year, date.month)));
}

class _WorkDayEditorDialog extends ConsumerStatefulWidget {
  const _WorkDayEditorDialog({required this.date});
  final DateTime date;

  @override
  ConsumerState<_WorkDayEditorDialog> createState() =>
      _WorkDayEditorDialogState();
}

class _WorkDayEditorDialogState extends ConsumerState<_WorkDayEditorDialog> {
  late final TextEditingController _activity;
  late final TextEditingController _note;
  var _include = true;
  var _metadataLoaded = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _activity = TextEditingController();
    _note = TextEditingController();
    _loadMetadata();
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
      if (mounted) setState(() => _error = error.toString());
    }
  }

  @override
  void dispose() {
    _activity.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<bool> _saveMetadata() async {
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
      ref.invalidate(daySummaryProvider(widget.date));
      ref.invalidate(
        monthSummaryProvider(DateTime(widget.date.year, widget.date.month)),
      );
      if (mounted) setState(() => _error = null);
      return true;
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
      return false;
    }
  }

  Future<void> _addPunch() async {
    final now = TimeOfDay.now();
    final picked = await showTimePicker(context: context, initialTime: now);
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
      ref.invalidate(daySummaryProvider(widget.date));
      ref.invalidate(
        monthSummaryProvider(DateTime(widget.date.year, widget.date.month)),
      );
      setState(() => _error = null);
    } catch (error) {
      setState(() => _error = error.toString().replaceFirst('Bad state: ', ''));
    }
  }

  Future<void> _editPunch(Punch punch) async {
    final local = punch.occurredAtLocal;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: local.hour, minute: local.minute),
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
      ref.invalidate(daySummaryProvider(widget.date));
      ref.invalidate(
        monthSummaryProvider(DateTime(widget.date.year, widget.date.month)),
      );
      setState(() => _error = null);
    } catch (error) {
      setState(() => _error = error.toString().replaceFirst('Bad state: ', ''));
    }
  }

  Future<void> _deletePunch(Punch punch) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Excluir batida?'),
            content: Text(
              'Excluir ${formatClock(punch.occurredAtLocal)}? O evento ficará registrado na auditoria.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Excluir'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    try {
      await ref.read(punchServiceProvider).deletePunch(punch.id, widget.date);
      ref.invalidate(daySummaryProvider(widget.date));
      ref.invalidate(
        monthSummaryProvider(DateTime(widget.date.year, widget.date.month)),
      );
      if (mounted) setState(() => _error = null);
    } catch (error) {
      if (mounted)
        setState(
          () => _error = error.toString().replaceFirst('Bad state: ', ''),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(daySummaryProvider(widget.date));
    return AlertDialog(
      title: Text('Revisar ${formatDateBr(widget.date)}'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) ...[
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 12),
              ],
              summary.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Text('Erro: $error'),
                data: (day) => Column(
                  children: [
                    for (var i = 0; i < day.punches.length; i++)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(child: Text('${i + 1}')),
                        title: Text(
                          formatClock(day.punches[i].occurredAtLocal),
                        ),
                        subtitle: Text(
                          day.punches[i].kind == PunchKind.in_
                              ? 'Entrada'
                              : 'Saída',
                        ),
                        trailing: Wrap(
                          children: [
                            IconButton(
                              tooltip: 'Editar horário',
                              onPressed: () => _editPunch(day.punches[i]),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              tooltip: 'Excluir batida',
                              onPressed: () => _deletePunch(day.punches[i]),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      ),
                    if (day.punches.length < 4)
                      OutlinedButton.icon(
                        onPressed: _addPunch,
                        icon: const Icon(Icons.add),
                        label: const Text('Adicionar batida manual'),
                      ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Total calculado: ${minutesToHhmm(day.workedMinutes)}',
                      ),
                    ),
                    if (day.issues.isNotEmpty)
                      for (final issue in day.issues)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '• ${issue.message}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                  ],
                ),
              ),
              const Divider(height: 28),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _include,
                onChanged: _metadataLoaded
                    ? (value) => setState(() => _include = value)
                    : null,
                title: const Text('Incluir no timesheet'),
              ),
              TextField(
                controller: _activity,
                enabled: _metadataLoaded,
                decoration: const InputDecoration(
                  labelText: 'Atividade do dia (opcional)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _note,
                enabled: _metadataLoaded,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Observação (opcional)',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fechar'),
        ),
        FilledButton(
          onPressed: _metadataLoaded
              ? () async {
                  final saved = await _saveMetadata();
                  if (saved && context.mounted) Navigator.pop(context);
                }
              : null,
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}
