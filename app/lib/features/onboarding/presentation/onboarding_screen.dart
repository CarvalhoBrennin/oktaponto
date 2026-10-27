import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/hf_semantics.dart';
import '../../../core/design/hf_tokens.dart';
import '../../../core/ui/hf_errors.dart';
import '../../../core/ui/hf_notice.dart';
import '../../../providers/app_providers.dart';
import '../../punch/domain/models.dart';
import '../../reminders/presentation/reminder_hooks.dart';
import '../../schedule/domain/work_schedule.dart';
import '../../schedule/presentation/schedule_provider.dart';
import '../../schedule/presentation/widgets/schedule_fields.dart';

/// Apresentação da primeira abertura.
///
/// A ideia é que ninguém precise entrar em Configurações para começar a usar:
/// aqui o usuário diz quem é e como é o dia dele, e a partir disso o app já
/// sabe a meta diária e a hora de avisar cada batida.
///
/// Tudo é pulável e tudo é editável depois — a apresentação é um atalho, não
/// um pedágio.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  final _name = TextEditingController();
  final _job = TextEditingController();

  late WorkSchedule _schedule;
  var _page = 0;
  var _saving = false;
  String? _error;

  static const _pageCount = 5;

  @override
  void initState() {
    super.initState();
    // Reabrir a apresentação a partir de Configurações mantém o que já existe.
    _schedule =
        ref.read(scheduleSetupProvider).value?.schedule ??
        WorkSchedule.defaults;
    final profile = ref.read(profileProvider).value;
    if (profile != null) {
      _name.text = profile.employeeName;
      _job.text = profile.jobTitle;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _name.dispose();
    _job.dispose();
    super.dispose();
  }

  void _update(WorkSchedule next) => setState(() {
    _schedule = next;
    _error = null;
  });

  void _goTo(int page) {
    setState(() => _page = page);
    _pageController.animateToPage(
      page,
      duration: HfMotion.base,
      curve: HfMotion.standard,
    );
  }

  Future<void> _skip() async {
    setState(() => _saving = true);
    try {
      await ref.read(scheduleSetupProvider.notifier).skipOnboarding();
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// `true` quando o aparelho autorizou notificações.
  ///
  /// Uma falha aqui é tratada como recusa: sem permissão, os lembretes ficam
  /// desligados, mas nada além disso é interrompido.
  Future<bool> _requestNotificationPermission() async {
    try {
      return await ref.read(notificationServiceProvider).requestPermissions();
    } catch (error, stackTrace) {
      logReminderFailure(error, stackTrace);
      return false;
    }
  }

  Future<void> _finish() async {
    final problem = _schedule.problem;
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    var scheduleSaved = false;
    try {
      if (_name.text.trim().isNotEmpty || _job.text.trim().isNotEmpty) {
        final current = ref.read(profileProvider).value;
        await ref
            .read(settingsRepositoryProvider)
            .saveProfile(
              (current ?? const ProfileSettingsModel()).copyWith(
                employeeName: _name.text.trim(),
                jobTitle: _job.text.trim(),
              ),
            );
        ref.invalidate(profileProvider);
      }
      // A permissão é pedida só quando o usuário de fato quer ser avisado, e
      // um "não" — ou uma falha no aparelho — desliga apenas os lembretes. A
      // jornada é salva de qualquer forma: perdê-la por causa de notificação
      // custaria ao usuário toda a configuração que ele acabou de fazer.
      var schedule = _schedule;
      if (schedule.remindersEnabled &&
          !await _requestNotificationPermission()) {
        schedule = schedule.copyWith(remindersEnabled: false);
      }
      await ref.read(scheduleSetupProvider.notifier).save(schedule);
      scheduleSaved = true;
      if (!mounted) return;
      await refreshRecurringReminders(ref, rethrowOnFailure: true);
    } catch (error) {
      if (mounted) {
        final message = scheduleSaved
            ? 'A jornada foi salva, mas os lembretes não foram atualizados. '
                  '${friendlyError(error)}'
            : friendlyError(error);
        setState(() => _error = message);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLast = _page == _pageCount - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _ProgressBar(page: _page, total: _pageCount),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  const _WelcomePage(),
                  _IdentityPage(name: _name, job: _job),
                  _HoursPage(schedule: _schedule, onChanged: _update),
                  _BreakPage(schedule: _schedule, onChanged: _update),
                  _RemindersPage(schedule: _schedule, onChanged: _update),
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  HfSpace.xl,
                  0,
                  HfSpace.xl,
                  HfSpace.md,
                ),
                child: HfNotice(tone: HfNoticeTone.attention, message: _error!),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                HfSpace.xl,
                HfSpace.sm,
                HfSpace.xl,
                HfSpace.xl,
              ),
              child: Row(
                children: [
                  if (_page > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving ? null : () => _goTo(_page - 1),
                        child: const Text('Voltar'),
                      ),
                    )
                  else
                    Expanded(
                      child: TextButton(
                        onPressed: _saving ? null : _skip,
                        child: const Text('Configurar depois'),
                      ),
                    ),
                  const SizedBox(width: HfSpace.md),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: HfSize.primaryAction,
                      child: FilledButton(
                        onPressed: _saving
                            ? null
                            : (isLast ? _finish : () => _goTo(_page + 1)),
                        style: FilledButton.styleFrom(
                          shape: const RoundedRectangleBorder(
                            borderRadius: HfRadius.large,
                          ),
                          textStyle: theme.textTheme.titleMedium,
                        ),
                        child: Text(
                          _saving
                              ? 'Salvando...'
                              : (isLast ? 'Começar a usar' : 'Continuar'),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.page, required this.total});

  final int page;
  final int total;

  @override
  Widget build(BuildContext context) {
    final hf = context.hf;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        HfSpace.xl,
        HfSpace.xl,
        HfSpace.xl,
        HfSpace.sm,
      ),
      child: Semantics(
        label: 'Passo ${page + 1} de $total',
        child: ExcludeSemantics(
          child: Row(
            children: [
              for (var i = 0; i < total; i++) ...[
                if (i > 0) const SizedBox(width: HfSpace.xs + 2),
                Expanded(
                  child: AnimatedContainer(
                    duration: HfMotion.base,
                    curve: HfMotion.standard,
                    height: 4,
                    decoration: BoxDecoration(
                      color: i <= page ? hf.working.foreground : hf.track,
                      borderRadius: HfRadius.pill,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Casca comum das páginas: título, subtítulo e conteúdo rolável.
class _Page extends StatelessWidget {
  const _Page({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        HfSpace.xl,
        HfSpace.xl,
        HfSpace.xl,
        HfSpace.xl,
      ),
      children: [
        Text(title, style: theme.textTheme.headlineMedium),
        const SizedBox(height: HfSpace.sm),
        Text(subtitle, style: theme.textTheme.bodyMedium),
        const SizedBox(height: HfSpace.huge),
        child,
      ],
    );
  }
}

class _WelcomePage extends StatelessWidget {
  const _WelcomePage();

  @override
  Widget build(BuildContext context) {
    return const _Page(
      title: 'Bem-vindo ao OktaPonto',
      subtitle:
          'Um lugar só para acompanhar a sua jornada de trabalho — sem conta, '
          'sem internet, tudo guardado neste aparelho.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HowItWorks(
            icon: Icons.touch_app_outlined,
            title: 'Quatro toques por dia',
            body:
                'Entrada, saída para o intervalo, retorno e saída final. '
                'A tela Hoje sempre mostra qual é o próximo.',
          ),
          _HowItWorks(
            icon: Icons.notifications_active_outlined,
            title: 'O app lembra por você',
            body:
                'A partir do horário que você combinar agora, ele avisa perto '
                'de cada batida.',
          ),
          _HowItWorks(
            icon: Icons.description_outlined,
            title: 'No fim do mês, o timesheet',
            body:
                'O OktaPonto junta os dias, aponta o que ficou pendente e '
                'gera a planilha para você compartilhar.',
          ),
        ],
      ),
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hf = context.hf;
    return Padding(
      padding: const EdgeInsets.only(bottom: HfSpace.xxl),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: hf.working.container,
              borderRadius: HfRadius.medium,
            ),
            child: Icon(icon, size: 20, color: hf.working.onContainer),
          ),
          const SizedBox(width: HfSpace.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(body, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IdentityPage extends StatelessWidget {
  const _IdentityPage({required this.name, required this.job});

  final TextEditingController name;
  final TextEditingController job;

  @override
  Widget build(BuildContext context) {
    return _Page(
      title: 'Como você assina?',
      subtitle:
          'Esses dados aparecem no cabeçalho do timesheet gerado no fim do '
          'mês. Dá para deixar em branco e preencher depois.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nome'),
          ),
          const SizedBox(height: HfSpace.lg),
          TextField(
            controller: job,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Cargo'),
          ),
        ],
      ),
    );
  }
}

class _HoursPage extends StatelessWidget {
  const _HoursPage({required this.schedule, required this.onChanged});

  final WorkSchedule schedule;
  final ValueChanged<WorkSchedule> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Page(
      title: 'Que horas é o seu dia?',
      subtitle:
          'Entrada e saída combinadas. O OktaPonto usa isso para calcular a '
          'sua jornada e para saber quando avisar.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ScheduleTimeField(
            label: 'Entrada',
            minuteOfDay: schedule.startMinuteOfDay,
            onChanged: (value) =>
                onChanged(schedule.copyWith(startMinuteOfDay: value)),
          ),
          const Divider(),
          ScheduleTimeField(
            label: 'Saída',
            minuteOfDay: schedule.endMinuteOfDay,
            onChanged: (value) =>
                onChanged(schedule.copyWith(endMinuteOfDay: value)),
          ),
          const SizedBox(height: HfSpace.xl),
          Text(
            schedule.problem ??
                'Com o intervalo do próximo passo, sua jornada fica em '
                    '${formatDuration(schedule.targetMinutes)} por dia.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _BreakPage extends StatelessWidget {
  const _BreakPage({required this.schedule, required this.onChanged});

  final WorkSchedule schedule;
  final ValueChanged<WorkSchedule> onChanged;

  @override
  Widget build(BuildContext context) {
    return _Page(
      title: 'Como é o seu intervalo?',
      subtitle: 'Almoço, descanso — o tempo que não conta como trabalhado.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BreakModeField(
            mode: schedule.breakMode,
            onChanged: (mode) => onChanged(schedule.copyWith(breakMode: mode)),
          ),
          const SizedBox(height: HfSpace.xl),
          ScheduleDurationField(
            label: 'Duração',
            minutes: schedule.breakMinutes,
            onChanged: (value) =>
                onChanged(schedule.copyWith(breakMinutes: value)),
            max: 4 * 60,
          ),
          if (schedule.breakMode == BreakMode.fixed) ...[
            const Divider(),
            ScheduleTimeField(
              label: 'Começa às',
              helpText: 'Início do intervalo',
              minuteOfDay: schedule.breakStartMinuteOfDay,
              onChanged: (value) =>
                  onChanged(schedule.copyWith(breakStartMinuteOfDay: value)),
            ),
          ],
          const SizedBox(height: HfSpace.xxl),
          ScheduleSummary(schedule: schedule),
        ],
      ),
    );
  }
}

class _RemindersPage extends StatelessWidget {
  const _RemindersPage({required this.schedule, required this.onChanged});

  final WorkSchedule schedule;
  final ValueChanged<WorkSchedule> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Page(
      title: 'Quer ser lembrado?',
      subtitle:
          'O OktaPonto avisa perto de cada batida, só nos dias em que você '
          'trabalha.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: schedule.remindersEnabled,
            onChanged: (value) =>
                onChanged(schedule.copyWith(remindersEnabled: value)),
            title: const Text('Avisar na hora de bater o ponto'),
          ),
          if (schedule.remindersEnabled) ...[
            const SizedBox(height: HfSpace.md),
            Text(
              'No Android, o sistema pode atrasar avisos para economizar '
              'bateria.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: HfSpace.xl),
            Text('DIAS DE TRABALHO', style: theme.textTheme.labelSmall),
            const SizedBox(height: HfSpace.md),
            WeekdayPickerField(
              mask: schedule.weekdaysMask,
              onChanged: (mask) =>
                  onChanged(schedule.copyWith(weekdaysMask: mask)),
            ),
            const SizedBox(height: HfSpace.lg),
            ScheduleDurationField(
              label: 'Avisar antes',
              minutes: schedule.leadMinutes,
              onChanged: (value) =>
                  onChanged(schedule.copyWith(leadMinutes: value)),
              step: 5,
              max: 60,
            ),
          ],
          const SizedBox(height: HfSpace.xxl),
          ScheduleSummary(schedule: schedule),
        ],
      ),
    );
  }
}
