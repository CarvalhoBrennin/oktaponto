import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/app_providers.dart';
import '../../punch/domain/models.dart';
import '../../reminders/domain/reminder.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _name = TextEditingController();
  final _job = TextEditingController();
  final _mode = TextEditingController();
  final _activity = TextEditingController();
  var _loadedProfile = false;
  var _saving = false;
  var _reminderBusy = false;
  var _resetBusy = false;

  static const _weekdayLabels = <String>[
    'Seg',
    'Ter',
    'Qua',
    'Qui',
    'Sex',
    'Sáb',
    'Dom',
  ];

  @override
  void dispose() {
    _name.dispose();
    _job.dispose();
    _mode.dispose();
    _activity.dispose();
    super.dispose();
  }

  void _scheduleHydrate(ProfileSettingsModel profile) {
    if (_loadedProfile) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _loadedProfile) return;
      _loadedProfile = true;
      _name.text = profile.employeeName;
      _job.text = profile.jobTitle;
      _mode.text = profile.workMode;
      _activity.text = profile.defaultActivity;
    });
  }

  String _friendlyError(Object error) =>
      error.toString().replaceFirst('Bad state: ', '');

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_friendlyError(error))),
    );
  }

  Future<void> _saveProfile() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(settingsRepositoryProvider).saveProfile(
            ProfileSettingsModel(
              employeeName: _name.text.trim(),
              jobTitle: _job.text.trim(),
              workMode: _mode.text.trim(),
              defaultActivity: _activity.text.trim(),
            ),
          );
      ref.invalidate(profileProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil salvo.')),
        );
      }
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _restoreReminderSchedule(
    List<ReminderConfig> previous,
  ) async {
    try {
      await ref.read(notificationServiceProvider).rescheduleAll(previous);
    } catch (_) {
      // Best effort. Startup reconciliation will retry from persisted state.
    }
  }

  Future<void> _editReminder([ReminderConfig? existing]) async {
    if (_reminderBusy) return;
    final label = TextEditingController(
      text: existing?.label ?? 'Lembrete para registrar o ponto',
    );
    var time = TimeOfDay(
      hour: existing?.hour ?? 8,
      minute: existing?.minute ?? 0,
    );
    var mask = existing?.weekdaysMask ?? 31;
    var enabled = existing?.enabled ?? true;
    final result = await showDialog<ReminderConfig>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Novo lembrete' : 'Editar lembrete'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: label,
                  decoration: const InputDecoration(labelText: 'Mensagem'),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Horário'),
                  trailing: Text(time.format(context)),
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: time,
                    );
                    if (picked != null) setDialogState(() => time = picked);
                  },
                ),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Dias da semana'),
                ),
                Wrap(
                  spacing: 4,
                  children: [
                    for (var day = 1; day <= 7; day++)
                      Semantics(
                        label: _weekdayLabels[day - 1],
                        button: true,
                        selected: (mask & (1 << (day - 1))) != 0,
                        child: FilterChip(
                          label: Text(_weekdayLabels[day - 1]),
                          selected: (mask & (1 << (day - 1))) != 0,
                          onSelected: (selected) => setDialogState(() {
                            if (selected) {
                              mask |= 1 << (day - 1);
                            } else {
                              mask &= ~(1 << (day - 1));
                            }
                          }),
                        ),
                      ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Ativo'),
                  value: enabled,
                  onChanged: (value) => setDialogState(() => enabled = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: mask == 0 || label.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(
                        context,
                        ReminderConfig(
                          id: existing?.id ?? 0,
                          label: label.text.trim(),
                          hour: time.hour,
                          minute: time.minute,
                          weekdaysMask: mask,
                          enabled: enabled,
                        ),
                      ),
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
    label.dispose();
    if (result == null || !mounted) return;

    setState(() => _reminderBusy = true);
    final repo = ref.read(reminderRepositoryProvider);
    final notifications = ref.read(notificationServiceProvider);
    var previous = <ReminderConfig>[];
    var snapshotLoaded = false;
    int? savedId;
    try {
      previous = await repo.listAll();
      snapshotLoaded = true;
      if (result.enabled) {
        final granted = await notifications.requestPermissions();
        if (!granted) {
          throw StateError(
            'A permissão de notificações foi negada. O lembrete não foi ativado.',
          );
        }
      }
      savedId = await repo.save(result);
      final all = await repo.listAll();
      await notifications.rescheduleAll(all);
      ref.invalidate(remindersProvider);
    } catch (error) {
      // Roll back persisted intent when OS scheduling fails. Only attempt a
      // rollback if the pre-change snapshot was loaded successfully.
      if (snapshotLoaded) {
        try {
          if (existing == null && savedId != null) {
            await repo.delete(savedId);
          } else if (existing != null) {
            await repo.save(existing);
          }
        } catch (_) {}
        await _restoreReminderSchedule(previous);
      }
      ref.invalidate(remindersProvider);
      _showError(error);
    } finally {
      if (mounted) setState(() => _reminderBusy = false);
    }
  }

  Future<void> _deleteReminder(ReminderConfig reminder) async {
    if (_reminderBusy) return;
    setState(() => _reminderBusy = true);
    final repo = ref.read(reminderRepositoryProvider);
    final notifications = ref.read(notificationServiceProvider);
    var previous = <ReminderConfig>[];
    var snapshotLoaded = false;
    var deleted = false;
    try {
      previous = await repo.listAll();
      snapshotLoaded = true;
      await repo.delete(reminder.id);
      deleted = true;
      final all = await repo.listAll();
      await notifications.rescheduleAll(all);
      ref.invalidate(remindersProvider);
    } catch (error) {
      if (snapshotLoaded) {
        if (deleted) {
          try {
            await repo.save(reminder);
          } catch (_) {}
        }
        await _restoreReminderSchedule(previous);
      }
      ref.invalidate(remindersProvider);
      _showError(error);
    } finally {
      if (mounted) setState(() => _reminderBusy = false);
    }
  }

  Future<void> _clearAll() async {
    if (_resetBusy) return;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Apagar todos os dados?'),
            content: const Text(
              'Batidas, histórico, perfil, lembretes e arquivos XLSX gerados '
              'serão apagados do dispositivo. Esta ação não pode ser desfeita.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Apagar tudo'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;

    setState(() => _resetBusy = true);
    try {
      // Cancel OS state first; if this fails, do not claim a full reset.
      await ref.read(notificationServiceProvider).cancelAll();
      await ref.read(dataResetServiceProvider).clearAll();
      _loadedProfile = false;
      _name.clear();
      _job.clear();
      _mode.clear();
      _activity.clear();
      ref.invalidate(profileProvider);
      ref.invalidate(remindersProvider);
      ref.invalidate(daySummaryProvider);
      ref.invalidate(monthSummaryProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Todos os dados e exports locais foram apagados.'),
          ),
        );
      }
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _resetBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final reminders = ref.watch(remindersProvider);
    profile.whenData(_scheduleHydrate);
    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Perfil do timesheet',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Colaborador'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _job,
            decoration: const InputDecoration(labelText: 'Cargo'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _mode,
            decoration: const InputDecoration(labelText: 'Modalidade'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _activity,
            decoration: const InputDecoration(labelText: 'Atividade padrão'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _saving ? null : _saveProfile,
            child: Text(_saving ? 'Salvando...' : 'Salvar perfil'),
          ),
          const Divider(height: 40),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Lembretes locais',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                onPressed: _reminderBusy ? null : () => _editReminder(),
                icon: const Icon(Icons.add_alert),
                tooltip: 'Novo lembrete',
              ),
            ],
          ),
          if (_reminderBusy) const LinearProgressIndicator(),
          reminders.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => Text('Erro ao carregar lembretes: $error'),
            data: (items) => Column(
              children: [
                if (items.isEmpty)
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Nenhum lembrete configurado.'),
                  ),
                for (final item in items)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      item.enabled
                          ? Icons.notifications_active_outlined
                          : Icons.notifications_off_outlined,
                    ),
                    title: Text(item.label),
                    subtitle: Text(
                      '${item.hour.toString().padLeft(2, '0')}:${item.minute.toString().padLeft(2, '0')}',
                    ),
                    onTap: _reminderBusy ? null : () => _editReminder(item),
                    trailing: IconButton(
                      onPressed:
                          _reminderBusy ? null : () => _deleteReminder(item),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 40),
          Text(
            'Privacidade e dados',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'O HoraFólio funciona sem login, backend, câmera, localização ou '
            'OCR. Os dados principais ficam no armazenamento privado do app.',
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _resetBusy ? null : _clearAll,
            icon: const Icon(Icons.delete_forever_outlined),
            label: Text(_resetBusy ? 'Apagando...' : 'Limpar todos os dados'),
          ),
        ],
      ),
    );
  }
}
