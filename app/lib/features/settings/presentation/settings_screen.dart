import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/hf_semantics.dart';
import '../../../core/design/hf_tokens.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/ui/hf_errors.dart';
import '../../../core/ui/hf_sheet.dart';
import '../../../providers/app_providers.dart';
import '../../punch/domain/models.dart';
import '../../reminders/domain/reminder.dart';
import '../../reminders/domain/reminder_sync.dart';
import '../../reminders/presentation/reminder_hooks.dart';
import '../../schedule/presentation/schedule_provider.dart';
import '../../schedule/presentation/widgets/schedule_settings_section.dart';
import 'widgets/settings_group.dart';

/// Configurações — linguagem de produto, não de implementação.
///
/// Nada aqui menciona seed, paleta tonal ou Material: o usuário escolhe como o
/// app se parece, quem assina o timesheet, quando ser lembrado e o que fazer
/// com os dados.
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

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _showError(Object error) => _showMessage(friendlyError(error));

  Future<void> _saveProfile() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(settingsRepositoryProvider)
          .saveProfile(
            ProfileSettingsModel(
              employeeName: _name.text.trim(),
              jobTitle: _job.text.trim(),
              workMode: _mode.text.trim(),
              defaultActivity: _activity.text.trim(),
            ),
          );
      ref.invalidate(profileProvider);
      _showMessage('Dados salvos.');
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _restoreReminderSchedule(List<ReminderConfig> previous) async {
    try {
      // Reagenda a lista anterior junto com a jornada: os dois compartilham o
      // agendador, e restaurar só a metade manual apagaria os avisos da jornada.
      await syncRecurringReminders(
        notifications: ref.read(notificationServiceProvider),
        manualReminders: previous,
        schedule: ref.read(workScheduleProvider),
      );
    } catch (_) {
      // Best effort. Startup reconciliation will retry from persisted state.
    }
  }

  Future<void> _editReminder([ReminderConfig? existing]) async {
    if (_reminderBusy) return;
    final result = await showHfSheet<ReminderConfig>(
      context: context,
      builder: (_) =>
          _ReminderSheet(existing: existing, weekdayLabels: _weekdayLabels),
    );
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
            'O aparelho não autorizou notificações, então o lembrete não foi '
            'ativado. Libere as notificações do OktaPonto e tente de novo.',
          );
        }
      }
      savedId = await repo.save(result);
      ref.invalidate(remindersProvider);
      await refreshRecurringReminders(ref, rethrowOnFailure: true);
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
    var previous = <ReminderConfig>[];
    var snapshotLoaded = false;
    var deleted = false;
    try {
      previous = await repo.listAll();
      snapshotLoaded = true;
      await repo.delete(reminder.id);
      deleted = true;
      ref.invalidate(remindersProvider);
      await refreshRecurringReminders(ref, rethrowOnFailure: true);
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

  /// Reabre a apresentação sobre a raiz da navegação — ela é uma tela
  /// inteira, não caberia empilhada sobre Configurações.
  void _replayOnboarding() {
    Navigator.of(context).popUntil((route) => route.isFirst);
    ref.read(scheduleSetupProvider.notifier).replayOnboarding();
  }

  Future<void> _clearAll() async {
    if (_resetBusy) return;
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Apagar tudo?'),
            content: const Text(
              'Horários, histórico, seus dados de timesheet, lembretes e os '
              'arquivos já gerados serão apagados deste aparelho. Não dá para '
              'desfazer.',
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
      // A jornada mora nas preferências do aparelho, fora do banco: limpar
      // tudo precisa devolver o app ao estado de primeira abertura.
      await ref.read(scheduleSetupProvider.notifier).reset();
      _loadedProfile = false;
      _name.clear();
      _job.clear();
      _mode.clear();
      _activity.clear();
      ref.invalidate(profileProvider);
      ref.invalidate(remindersProvider);
      ref.invalidate(daySummaryProvider);
      ref.invalidate(monthSummaryProvider);
      _showMessage('Tudo apagado deste aparelho.');
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _resetBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = ref.watch(profileProvider);
    final reminders = ref.watch(remindersProvider);
    final themeMode = ref.watch(themeModeProvider);
    profile.whenData(_scheduleHydrate);

    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          HfSpace.xl,
          HfSpace.sm,
          HfSpace.xl,
          HfSpace.section,
        ),
        children: [
          SettingsGroup(
            first: true,
            title: 'Aparência',
            description: 'Como o OktaPonto se apresenta neste aparelho.',
            children: [
              SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.system,
                    label: Text('Automático'),
                    icon: Icon(Icons.brightness_auto_outlined),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    label: Text('Claro'),
                    icon: Icon(Icons.light_mode_outlined),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    label: Text('Escuro'),
                    icon: Icon(Icons.dark_mode_outlined),
                  ),
                ],
                selected: {themeMode},
                showSelectedIcon: false,
                onSelectionChanged: (selection) async {
                  if (selection.isEmpty) return;
                  try {
                    await ref
                        .read(themeModeProvider.notifier)
                        .setMode(selection.first);
                  } catch (error) {
                    _showError(error);
                  }
                },
              ),
              const SizedBox(height: HfSpace.sm),
              Text(
                themeMode == ThemeMode.system
                    ? 'Acompanha o modo claro ou escuro do sistema.'
                    : themeMode == ThemeMode.light
                    ? 'Sempre claro, independente do sistema.'
                    : 'Sempre escuro, independente do sistema.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          const ScheduleSettingsSection(),
          SettingsGroup(
            title: 'Seus dados no timesheet',
            description:
                'Aparecem no cabeçalho do arquivo gerado no fechamento do mês.',
            children: [
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nome'),
              ),
              const SizedBox(height: HfSpace.md),
              TextField(
                controller: _job,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Cargo'),
              ),
              const SizedBox(height: HfSpace.md),
              TextField(
                controller: _mode,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Modalidade',
                  helperText: 'Presencial, remoto, híbrido...',
                ),
              ),
              const SizedBox(height: HfSpace.md),
              TextField(
                controller: _activity,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Atividade padrão',
                  helperText: 'Usada nos dias sem atividade específica',
                ),
              ),
              const SizedBox(height: HfSpace.lg),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton(
                  onPressed: _saving ? null : _saveProfile,
                  child: Text(_saving ? 'Salvando...' : 'Salvar'),
                ),
              ),
            ],
          ),
          SettingsGroup(
            title: 'Outros lembretes',
            description: 'Avisos avulsos, além dos que a sua jornada já gera.',
            trailing: IconButton(
              onPressed: _reminderBusy ? null : () => _editReminder(),
              icon: const Icon(Icons.add_rounded),
              tooltip: 'Novo lembrete',
            ),
            children: [
              if (_reminderBusy)
                const Padding(
                  padding: EdgeInsets.only(bottom: HfSpace.md),
                  child: LinearProgressIndicator(),
                ),
              reminders.when(
                loading: () => const LinearProgressIndicator(),
                error: (error, _) => Text(
                  'Não foi possível carregar seus lembretes.',
                  style: theme.textTheme.bodyMedium,
                ),
                data: (items) => items.isEmpty
                    ? Text(
                        'Nenhum lembrete ainda. Toque em + para criar um.',
                        style: theme.textTheme.bodyMedium,
                      )
                    : Column(
                        children: [
                          for (final item in items)
                            _ReminderRow(
                              reminder: item,
                              weekdayLabels: _weekdayLabels,
                              enabled: !_reminderBusy,
                              onEdit: () => _editReminder(item),
                              onDelete: () => _deleteReminder(item),
                            ),
                        ],
                      ),
              ),
            ],
          ),
          SettingsGroup(
            title: 'Dados e privacidade',
            description:
                'O OktaPonto funciona sem conta, sem internet e sem acesso a '
                'câmera ou localização. Tudo fica guardado só neste aparelho.',
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _replayOnboarding,
                  icon: const Icon(Icons.replay_rounded, size: 20),
                  label: const Text('Rever a apresentação inicial'),
                ),
              ),
              const SizedBox(height: HfSpace.md),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _resetBusy ? null : _clearAll,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                    side: BorderSide(color: theme.colorScheme.error),
                  ),
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  label: Text(
                    _resetBusy ? 'Apagando...' : 'Apagar todos os dados',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReminderRow extends StatelessWidget {
  const _ReminderRow({
    required this.reminder,
    required this.weekdayLabels,
    required this.enabled,
    required this.onEdit,
    required this.onDelete,
  });

  final ReminderConfig reminder;
  final List<String> weekdayLabels;
  final bool enabled;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  String get _days {
    final active = <String>[
      for (var day = 1; day <= 7; day++)
        if (reminder.includesWeekday(day)) weekdayLabels[day - 1],
    ];
    if (active.length == 7) return 'Todos os dias';
    if (active.length == 5 &&
        !reminder.includesWeekday(6) &&
        !reminder.includesWeekday(7)) {
      return 'Dias úteis';
    }
    return active.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hf = context.hf;
    final role = reminder.enabled ? hf.working : hf.idle;

    return InkWell(
      onTap: enabled ? onEdit : null,
      borderRadius: HfRadius.medium,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: HfSpace.md),
        child: Row(
          children: [
            Icon(
              reminder.enabled
                  ? Icons.notifications_active_outlined
                  : Icons.notifications_off_outlined,
              size: 20,
              color: role.foreground,
            ),
            const SizedBox(width: HfSpace.md),
            SizedBox(
              width: 56,
              child: Text(
                '${reminder.hour.toString().padLeft(2, '0')}:'
                '${reminder.minute.toString().padLeft(2, '0')}',
                style: theme.textTheme.titleMedium,
              ),
            ),
            const SizedBox(width: HfSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reminder.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge,
                  ),
                  Text(
                    reminder.enabled ? _days : '$_days · desativado',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: enabled ? onDelete : null,
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
              tooltip: 'Apagar lembrete',
            ),
          ],
        ),
      ),
    );
  }
}

/// Criação/edição de lembrete em folha inferior, com horário, dias e estado.
class _ReminderSheet extends StatefulWidget {
  const _ReminderSheet({required this.existing, required this.weekdayLabels});

  final ReminderConfig? existing;
  final List<String> weekdayLabels;

  @override
  State<_ReminderSheet> createState() => _ReminderSheetState();
}

class _ReminderSheetState extends State<_ReminderSheet> {
  late final TextEditingController _label;
  late TimeOfDay _time;
  late int _mask;
  late bool _enabled;

  @override
  void initState() {
    super.initState();
    _label = TextEditingController(
      text: widget.existing?.label ?? 'Hora de registrar o ponto',
    );
    _time = TimeOfDay(
      hour: widget.existing?.hour ?? 8,
      minute: widget.existing?.minute ?? 0,
    );
    // Padrão: dias úteis.
    _mask = widget.existing?.weekdaysMask ?? 31;
    _enabled = widget.existing?.enabled ?? true;
  }

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final valid = _mask != 0 && _label.text.trim().isNotEmpty;

    return HfSheetScaffold(
      title: widget.existing == null ? 'Novo lembrete' : 'Editar lembrete',
      footer: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
          ),
          const SizedBox(width: HfSpace.md),
          Expanded(
            child: FilledButton(
              onPressed: valid
                  ? () => Navigator.pop(
                      context,
                      ReminderConfig(
                        id: widget.existing?.id ?? 0,
                        label: _label.text.trim(),
                        hour: _time.hour,
                        minute: _time.minute,
                        weekdaysMask: _mask,
                        enabled: _enabled,
                      ),
                    )
                  : null,
              child: const Text('Salvar'),
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: HfRadius.medium,
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: _time,
                helpText: 'HORÁRIO DO LEMBRETE',
                confirmText: 'Confirmar',
                cancelText: 'Cancelar',
              );
              if (picked != null) setState(() => _time = picked);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: HfSpace.sm),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Horário', style: theme.textTheme.bodyLarge),
                  ),
                  Text(
                    _time.format(context),
                    style: theme.textTheme.displaySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: HfSpace.xl),
          Text('REPETIR EM', style: theme.textTheme.labelSmall),
          const SizedBox(height: HfSpace.md),
          Wrap(
            spacing: HfSpace.sm,
            runSpacing: HfSpace.sm,
            children: [
              for (var day = 1; day <= 7; day++)
                FilterChip(
                  label: Text(widget.weekdayLabels[day - 1]),
                  selected: (_mask & (1 << (day - 1))) != 0,
                  onSelected: (selected) => setState(() {
                    if (selected) {
                      _mask |= 1 << (day - 1);
                    } else {
                      _mask &= ~(1 << (day - 1));
                    }
                  }),
                ),
            ],
          ),
          if (_mask == 0)
            Padding(
              padding: const EdgeInsets.only(top: HfSpace.sm),
              child: Text(
                'Escolha pelo menos um dia.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          const SizedBox(height: HfSpace.xl),
          TextField(
            controller: _label,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Mensagem do aviso'),
          ),
          const SizedBox(height: HfSpace.md),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _enabled,
            onChanged: (value) => setState(() => _enabled = value),
            title: const Text('Lembrete ativo'),
          ),
        ],
      ),
    );
  }
}
