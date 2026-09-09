import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/time_utils.dart';
import '../../../providers/app_providers.dart';
import '../../punch/domain/models.dart';

class MonthScreen extends ConsumerStatefulWidget {
  const MonthScreen({super.key});

  @override
  ConsumerState<MonthScreen> createState() => _MonthScreenState();
}

class _MonthScreenState extends ConsumerState<MonthScreen> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  var _busy = false;
  TimesheetGenerationResult? _lastExport;
  String? _error;

  void _move(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      _lastExport = null;
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
      final result = await ref.read(timesheetExporterProvider).exportMonth(month, profile, directory);
      if (!mounted) return;
      setState(() => _lastExport = result);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncMonth = ref.watch(monthSummaryProvider(_month));
    return Scaffold(
      appBar: AppBar(title: const Text('Fechamento do mês')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              IconButton(onPressed: () => _move(-1), icon: const Icon(Icons.chevron_left)),
              Expanded(child: Text(monthYearPt(_month), textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium)),
              IconButton(onPressed: () => _move(1), icon: const Icon(Icons.chevron_right)),
            ],
          ),
          const SizedBox(height: 12),
          asyncMonth.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
            error: (error, _) => Text('Erro: $error'),
            data: (month) {
              final validation = ref.watch(monthlyValidatorProvider).validate(month);
              final included = month.days.where((d) => d.includeInTimesheet).length;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Total elegível: ${minutesToHhmm(month.totalMinutes)}', style: Theme.of(context).textTheme.headlineSmall),
                          const SizedBox(height: 4),
                          Text('$included dias marcados para o timesheet'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (!validation.isValid) ...[
                    Text('Pendências que bloqueiam a exportação', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    for (final issue in validation.issues.where((i) => i.blocking))
                      Card(
                        child: ListTile(
                          leading: Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
                          title: Text(issue.message),
                        ),
                      ),
                  ] else
                    const Card(
                      child: ListTile(
                        leading: Icon(Icons.check_circle_outline),
                        title: Text('Mês consistente e pronto para exportar.'),
                      ),
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: validation.isValid && !_busy ? () => _export(month) : null,
                    icon: _busy
                        ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.description_outlined),
                    label: const Padding(padding: EdgeInsets.symmetric(vertical: 13), child: Text('Gerar timesheet XLSX')),
                  ),
                  if (_lastExport != null) ...[
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text('Arquivo gerado'),
                            const SizedBox(height: 4),
                            Text(File(_lastExport!.outputPath).path.split(Platform.pathSeparator).last, style: Theme.of(context).textTheme.titleMedium),
                            Text('${_lastExport!.includedDays} dias • ${minutesToHhmm(_lastExport!.totalMinutes)}'),
                            const SizedBox(height: 12),
                            FilledButton.tonalIcon(
                              onPressed: () => ref.read(shareServiceProvider).shareXlsx(
                                    _lastExport!.outputPath,
                                    monthYear: _lastExport!.monthYear,
                                  ),
                              icon: const Icon(Icons.share_outlined),
                              label: const Text('Compartilhar'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
