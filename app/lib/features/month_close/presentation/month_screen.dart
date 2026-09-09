import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/time_utils.dart';
import '../../../providers/app_providers.dart';
import '../../punch/domain/models.dart';
import '../../timesheet/domain/timesheet_source_signature.dart';

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
      setState(() => _error = _friendlyError(error));
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
      final currentMonth = await ref.refresh(monthSummaryProvider(_month).future);
      final profile = await ref.read(settingsRepositoryProvider).getProfile();
      final currentSignature = timesheetSourceSignature(currentMonth, profile);
      if (currentSignature != signature) {
        throw StateError(
          'Os dados mudaram desde a última geração. Gere o timesheet novamente antes de compartilhar.',
        );
      }
      if (!await File(export.outputPath).exists()) {
        throw StateError(
          'O arquivo exportado não existe mais. Gere o timesheet novamente.',
        );
      }
      await ref.read(shareServiceProvider).shareXlsx(
            export.outputPath,
            monthYear: export.monthYear,
          );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _friendlyError(error);
        if (error is StateError) {
          _lastExport = null;
          _lastExportSignature = null;
        }
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _friendlyError(Object error) =>
      error.toString().replaceFirst('Bad state: ', '');

  @override
  Widget build(BuildContext context) {
    final asyncMonth = ref.watch(monthSummaryProvider(_month));
    final asyncProfile = ref.watch(profileProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Fechamento do mês')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => _move(-1),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  monthYearPt(_month),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                onPressed: () => _move(1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 12),
          asyncMonth.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (error, _) => Text('Erro: $error'),
            data: (month) {
              final validation = ref.watch(monthlyValidatorProvider).validate(month);
              final included =
                  month.days.where((d) => d.includeInTimesheet).length;
              final currentProfile = asyncProfile.asData?.value;
              final exportIsCurrent = _lastExport != null &&
                  _lastExportSignature != null &&
                  currentProfile != null &&
                  timesheetSourceSignature(month, currentProfile) ==
                      _lastExportSignature;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total elegível: ${minutesToHhmm(month.totalMinutes)}',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 4),
                          Text('$included dias marcados para o timesheet'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (!validation.isValid) ...[
                    Text(
                      'Pendências que bloqueiam a exportação',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    for (final issue
                        in validation.issues.where((i) => i.blocking))
                      Card(
                        child: ListTile(
                          leading: Icon(
                            Icons.error_outline,
                            color: Theme.of(context).colorScheme.error,
                          ),
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
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed:
                        validation.isValid && !_busy ? () => _export(month) : null,
                    icon: _busy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.description_outlined),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 13),
                      child: Text('Gerar timesheet XLSX'),
                    ),
                  ),
                  if (_lastExport != null && !exportIsCurrent) ...[
                    const SizedBox(height: 12),
                    const Card(
                      child: ListTile(
                        leading: Icon(Icons.refresh),
                        title: Text('Os dados mudaram após a última exportação.'),
                        subtitle: Text(
                          'Gere o timesheet novamente para habilitar o compartilhamento.',
                        ),
                      ),
                    ),
                  ],
                  if (_lastExport != null && exportIsCurrent) ...[
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text('Arquivo gerado'),
                            const SizedBox(height: 4),
                            Text(
                              File(_lastExport!.outputPath)
                                  .path
                                  .split(Platform.pathSeparator)
                                  .last,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              '${_lastExport!.includedDays} dias • ${minutesToHhmm(_lastExport!.totalMinutes)}',
                            ),
                            const SizedBox(height: 12),
                            FilledButton.tonalIcon(
                              onPressed: _busy ? null : _shareCurrent,
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
