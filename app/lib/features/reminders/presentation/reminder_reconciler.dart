import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/time_utils.dart';
import '../../../providers/app_providers.dart';
import 'reminder_hooks.dart';

/// Reconciles persisted reminder intent with the operating-system schedule on
/// startup and every time the app comes back to the foreground. A failure does
/// not block the time-clock app; it is logged and the next resume, settings
/// edit or startup retries reconciliation.
///
/// São duas reconciliações: os avisos (jornada + lista manual) e o aviso de fim
/// de intervalo, que pode ter ficado desatualizado se o usuário bateu o retorno
/// com o app fechado ou se a jornada mudou no meio do dia. Os avisos da jornada
/// têm janela de dias; reconciliar ao voltar mantém essa janela sempre à frente.
class ReminderReconciler extends ConsumerStatefulWidget {
  const ReminderReconciler({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<ReminderReconciler> createState() => _ReminderReconcilerState();
}

class _ReminderReconcilerState extends ConsumerState<ReminderReconciler>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future<void>.microtask(_reconcile);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _reconcile();
  }

  Future<void> _reconcile() async {
    await refreshRecurringReminders(ref);
    if (!mounted) return;
    await refreshBreakReminder(ref, dateOnly(ref.read(clockProvider).now()));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
