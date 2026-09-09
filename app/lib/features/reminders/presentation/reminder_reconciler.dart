import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/app_providers.dart';

/// Reconciles persisted reminder intent with the operating-system schedule on
/// startup. A failure does not block the time-clock app; it is logged and the
/// next settings edit/startup retries reconciliation.
class ReminderReconciler extends ConsumerStatefulWidget {
  const ReminderReconciler({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<ReminderReconciler> createState() =>
      _ReminderReconcilerState();
}

class _ReminderReconcilerState extends ConsumerState<ReminderReconciler> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_reconcile);
  }

  Future<void> _reconcile() async {
    try {
      final reminders = await ref.read(reminderRepositoryProvider).listAll();
      await ref.read(notificationServiceProvider).rescheduleAll(reminders);
    } catch (error, stackTrace) {
      debugPrint('Falha ao reconciliar lembretes locais: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
