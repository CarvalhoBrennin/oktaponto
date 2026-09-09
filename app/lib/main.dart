import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'features/reminders/data/local_notification_service.dart';
import 'features/reminders/presentation/reminder_reconciler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await LocalNotificationService.instance.initialize();
  } catch (error, stackTrace) {
    debugPrint('Falha ao inicializar lembretes locais: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
  runApp(
    const ProviderScope(
      child: ReminderReconciler(child: HoraFolioApp()),
    ),
  );
}
