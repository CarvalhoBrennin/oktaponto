import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/time_utils.dart';
import '../../../providers/app_providers.dart';
import '../../punch/domain/models.dart';
import '../../punch/presentation/work_day_editor.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  void _move(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
  }

  String _status(WorkDayStatus status) => switch (status) {
        WorkDayStatus.empty => 'Vazio',
        WorkDayStatus.open => 'Aberto',
        WorkDayStatus.paused => 'Incompleto',
        WorkDayStatus.complete => 'Completo',
        WorkDayStatus.invalid => 'Inválido',
      };

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(monthSummaryProvider(_month));
    return Scaffold(
      appBar: AppBar(title: const Text('Histórico')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Row(
              children: [
                IconButton(onPressed: () => _move(-1), icon: const Icon(Icons.chevron_left), tooltip: 'Mês anterior'),
                Expanded(
                  child: Text(monthYearPt(_month), textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
                ),
                IconButton(onPressed: () => _move(1), icon: const Icon(Icons.chevron_right), tooltip: 'Próximo mês'),
              ],
            ),
          ),
          Expanded(
            child: summary.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Padding(padding: const EdgeInsets.all(20), child: Text('Erro: $error'))),
              data: (month) {
                if (month.days.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.event_busy, size: 48),
                        const SizedBox(height: 12),
                        const Text('Nenhum registro neste mês.'),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: () => showWorkDayEditor(context, ref, DateTime(_month.year, _month.month, 1)),
                          child: const Text('Adicionar correção manual'),
                        ),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.refresh(monthSummaryProvider(_month).future),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                    itemCount: month.days.length,
                    itemBuilder: (context, index) {
                      final day = month.days[index];
                      return Card(
                        child: ListTile(
                          onTap: () => showWorkDayEditor(context, ref, day.date),
                          leading: CircleAvatar(child: Text('${day.date.day}')),
                          title: Text(weekdayPt(day.date)),
                          subtitle: Text('${_status(day.status)} • ${day.punches.length} batidas${day.includeInTimesheet ? '' : ' • fora do timesheet'}'),
                          trailing: Text(minutesToHhmm(day.workedMinutes), style: Theme.of(context).textTheme.titleMedium),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final initial = DateTime(_month.year, _month.month, 1);
          final last = DateTime(_month.year, _month.month + 1, 0);
          final picked = await showDatePicker(context: context, initialDate: initial, firstDate: initial, lastDate: last);
          if (picked != null && context.mounted) await showWorkDayEditor(context, ref, picked);
        },
        icon: const Icon(Icons.add),
        label: const Text('Correção'),
      ),
    );
  }
}
