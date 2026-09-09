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

  @override
  void dispose() {
    _name.dispose();
    _job.dispose();
    _mode.dispose();
    _activity.dispose();
    super.dispose();
  }

  void _hydrate(ProfileSettingsModel profile) {
    if (_loadedProfile) return;
    _loadedProfile = true;
    _name.text = profile.employeeName;
    _job.text = profile.jobTitle;
    _mode.text = profile.workMode;
    _activity.text = profile.defaultActivity;
  }

  Future<void> _saveProfile() async {
    setState(() => _saving = true);
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
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Perfil salvo.')));
    }
  }

  Future<void> _editReminder([ReminderConfig? existing]) async {
    final label = TextEditingController(text: existing?.label ?? 'Lembrete para registrar o ponto');
    var time = TimeOfDay(hour: existing?.hour ?? 8, minute: existing?.minute ?? 0);
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
                TextField(controller: label, decoration: const InputDecoration(labelText: 'Mensagem')),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Horário'),
                  trailing: Text(time.format(context)),
                  onTap: () async {
                    final picked = await showTimePicker(context: context, initialTime: time);
                    if (picked != null) setDialogState(() => time = picked);
                  },
                ),
                const Align(alignment: Alignment.centerLeft, child: Text('Dias da semana')),
                Wrap(
                  spacing: 4,
                  children: [
                    for (var day = 1; day <= 7; day++)
                      FilterChip(
                        label: Text(const ['S', 'T', 'Q', 'Q', 'S', 'S', 'D'][day - 1]),
                        selected: (mask & (1 << (day - 1))) != 0,
                        onSelected: (selected) => setDialogState(() {
                          if (selected) {
                            mask |= 1 << (day - 1);
                          } else {
                            mask &= ~(1 << (day - 1));
                          }
                        }),
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
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
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
    if (result == null) return;
    final repo = ref.read(reminderRepositoryProvider);
    await ref.read(notificationServiceProvider).requestPermissions();
    await repo.save(result);
    final all = await repo.listAll();
    await ref.read(notificationServiceProvider).rescheduleAll(all);
    ref.invalidate(remindersProvider);
  }

  Future<void> _deleteReminder(ReminderConfig reminder) async {
    await ref.read(reminderRepositoryProvider).delete(reminder.id);
    final all = await ref.read(reminderRepositoryProvider).listAll();
    await ref.read(notificationServiceProvider).rescheduleAll(all);
    ref.invalidate(remindersProvider);
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Apagar todos os dados?'),
            content: const Text('Batidas, histórico, perfil e lembretes serão apagados do dispositivo. Esta ação não pode ser desfeita.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Apagar tudo')),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    await ref.read(dataResetServiceProvider).clearAll();
    await ref.read(notificationServiceProvider).rescheduleAll(const []);
    _loadedProfile = false;
    ref.invalidate(profileProvider);
    ref.invalidate(remindersProvider);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dados apagados.')));
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final reminders = ref.watch(remindersProvider);
    profile.whenData(_hydrate);
    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Perfil do timesheet', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Colaborador')),
          const SizedBox(height: 12),
          TextField(controller: _job, decoration: const InputDecoration(labelText: 'Cargo')),
          const SizedBox(height: 12),
          TextField(controller: _mode, decoration: const InputDecoration(labelText: 'Modalidade')),
          const SizedBox(height: 12),
          TextField(controller: _activity, decoration: const InputDecoration(labelText: 'Atividade padrão')),
          const SizedBox(height: 12),
          FilledButton(onPressed: _saving ? null : _saveProfile, child: Text(_saving ? 'Salvando...' : 'Salvar perfil')),
          const Divider(height: 40),
          Row(
            children: [
              Expanded(child: Text('Lembretes locais', style: Theme.of(context).textTheme.titleLarge)),
              IconButton(onPressed: () => _editReminder(), icon: const Icon(Icons.add_alert), tooltip: 'Novo lembrete'),
            ],
          ),
          reminders.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => Text('Erro ao carregar lembretes: $error'),
            data: (items) => Column(
              children: [
                if (items.isEmpty) const ListTile(contentPadding: EdgeInsets.zero, title: Text('Nenhum lembrete configurado.')),
                for (final item in items)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(item.enabled ? Icons.notifications_active_outlined : Icons.notifications_off_outlined),
                    title: Text(item.label),
                    subtitle: Text('${item.hour.toString().padLeft(2, '0')}:${item.minute.toString().padLeft(2, '0')}'),
                    onTap: () => _editReminder(item),
                    trailing: IconButton(onPressed: () => _deleteReminder(item), icon: const Icon(Icons.delete_outline)),
                  ),
              ],
            ),
          ),
          const Divider(height: 40),
          Text('Privacidade e dados', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text('O HoraFólio funciona sem login, backend, câmera, localização ou OCR. Os dados principais ficam no armazenamento privado do app.'),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _clearAll,
            icon: const Icon(Icons.delete_forever_outlined),
            label: const Text('Limpar todos os dados'),
          ),
        ],
      ),
    );
  }
}
