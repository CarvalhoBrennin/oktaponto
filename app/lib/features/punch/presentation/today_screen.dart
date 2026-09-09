import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/time_utils.dart';
import '../../../providers/app_providers.dart';
import '../domain/models.dart';
import 'work_day_editor.dart';

class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen>
    with WidgetsBindingObserver {
  var _busy = false;
  String? _error;
  late DateTime _today;
  Timer? _midnightTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _today = dateOnly(ref.read(clockProvider).now());
    _scheduleMidnightRefresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _midnightTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshCurrentDate();
    }
  }

  void _scheduleMidnightRefresh() {
    _midnightTimer?.cancel();
    final now = ref.read(clockProvider).now();
    final nextDay = DateTime(now.year, now.month, now.day + 1);
    var delay = nextDay.difference(now);
    if (delay <= Duration.zero) delay = const Duration(seconds: 1);
    _midnightTimer = Timer(delay + const Duration(seconds: 1), () {
      _refreshCurrentDate();
      _scheduleMidnightRefresh();
    });
  }

  void _refreshCurrentDate() {
    if (!mounted) return;
    final current = dateOnly(ref.read(clockProvider).now());
    if (current == _today) return;
    final previous = _today;
    setState(() {
      _today = current;
      _error = null;
    });
    ref.invalidate(daySummaryProvider(previous));
    ref.invalidate(daySummaryProvider(current));
    _scheduleMidnightRefresh();
  }

  String _cta(int count) => switch (count) {
    0 => 'Registrar entrada',
    1 => 'Registrar saída',
    2 => 'Registrar retorno',
    3 => 'Registrar saída final',
    _ => 'Dia completo',
  };

  String _status(WorkDayStatus status) => switch (status) {
    WorkDayStatus.empty => 'Não iniciado',
    WorkDayStatus.open => 'Trabalhando',
    WorkDayStatus.paused => 'Intervalo',
    WorkDayStatus.complete => 'Completo',
    WorkDayStatus.invalid => 'Revisão necessária',
  };

  Future<void> _register(DateTime today) async {
    if (_busy) return;
    _refreshCurrentDate();
    if (today != _today) {
      setState(() => _error = 'A data mudou. Tente registrar novamente.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(punchServiceProvider).registerNextPunch(today);
      ref.invalidate(daySummaryProvider(today));
      ref.invalidate(monthSummaryProvider(DateTime(today.year, today.month)));
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Bad state: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = _today;
    final summary = ref.watch(daySummaryProvider(today));
    return Scaffold(
      appBar: AppBar(title: const Text('Hoje')),
      body: RefreshIndicator(
        onRefresh: () async {
          _refreshCurrentDate();
          await ref.refresh(daySummaryProvider(_today).future);
        },
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              formatDateBr(today),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ),
            summary.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, _) => Text('Falha ao carregar o dia: $error'),
              data: (day) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _status(day.status),
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 6),
                          Text('Total: ${minutesToHhmm(day.workedMinutes)}'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (var i = 0; i < day.punches.length; i++)
                    Card(
                      child: ListTile(
                        leading: Icon(
                          day.punches[i].kind == PunchKind.in_
                              ? Icons.login
                              : Icons.logout,
                        ),
                        title: Text(
                          formatClock(day.punches[i].occurredAtLocal),
                        ),
                        subtitle: Text(
                          day.punches[i].kind == PunchKind.in_
                              ? 'Entrada'
                              : 'Saída',
                        ),
                        trailing: day.punches[i].isEdited
                            ? const Icon(Icons.edit, size: 18)
                            : null,
                      ),
                    ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed:
                        _busy ||
                            day.punches.length >= 4 ||
                            day.status == WorkDayStatus.invalid
                        ? null
                        : () => _register(today),
                    icon: _busy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.fingerprint),
                    label: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Text(_cta(day.punches.length)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => showWorkDayEditor(context, ref, today),
                    icon: const Icon(Icons.edit_calendar_outlined),
                    label: const Text('Revisar / corrigir dia'),
                  ),
                  if (day.issues.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    for (final issue in day.issues)
                      Text(
                        '• ${issue.message}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
