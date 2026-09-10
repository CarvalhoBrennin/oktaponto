import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/hf_tokens.dart';
import '../../../core/time/time_utils.dart';
import '../../../core/ui/hf_errors.dart';
import '../../../core/ui/hf_notice.dart';
import '../../../core/ui/hf_section.dart';
import '../../../core/ui/hf_states.dart';
import '../../../providers/app_providers.dart';
import '../../reminders/presentation/reminder_hooks.dart';
import '../../schedule/presentation/schedule_provider.dart';
import '../../settings/presentation/settings_button.dart';
import '../domain/models.dart';
import '../domain/workday_progress.dart';
import 'widgets/live_journey.dart';
import 'widgets/punch_button.dart';
import 'widgets/time_hero.dart';
import 'widgets/workday_timeline.dart';
import 'work_day_editor.dart';

/// Tela Hoje — a assinatura visual do OktaPonto.
///
/// A leitura foi desenhada para responder três perguntas em segundos: estou
/// trabalhando agora, quanto já trabalhei e qual é o próximo passo. Daí a
/// ordem herói de tempo → ação → linha da jornada, e daí o fato de nenhuma
/// estatística mensal disputar espaço aqui.
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

  Future<void> _register(DateTime today) async {
    if (_busy) return;
    _refreshCurrentDate();
    if (today != _today) {
      setState(() => _error = 'O dia virou. Toque de novo para registrar.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(punchServiceProvider).registerNextPunch(today);
      // Retorno tátil só no momento que importa: o ponto foi gravado.
      unawaited(HapticFeedback.mediumImpact());
      ref.invalidate(daySummaryProvider(today));
      ref.invalidate(monthSummaryProvider(DateTime(today.year, today.month)));
      // Sair para o intervalo arma o aviso de retorno; voltar cancela.
      unawaited(refreshBreakReminder(ref, today));
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _review() => showWorkDayEditor(context, ref, _today);

  @override
  Widget build(BuildContext context) {
    final today = _today;
    final theme = Theme.of(context);
    final summary = ref.watch(daySummaryProvider(today));
    final targetMinutes = ref.watch(dailyTargetMinutesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hoje'),
        actions: const [SettingsButton()],
      ),
      body: RefreshIndicator(
        onRefresh: () => guardedRefresh(() async {
          _refreshCurrentDate();
          return ref.refresh(daySummaryProvider(_today).future);
        }),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            HfSpace.xl,
            0,
            HfSpace.xl,
            HfSpace.giant,
          ),
          children: [
            Text(
              '${weekdayPt(today)} · ${dayAndMonthPt(today)}',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: HfSpace.xxl),
            summary.when(
              loading: _TodaySkeleton.new,
              error: (error, _) => const Padding(
                padding: EdgeInsets.only(top: HfSpace.huge),
                child: HfNotice(
                  tone: HfNoticeTone.error,
                  title: 'Não foi possível carregar o dia',
                  message:
                      'Puxe a tela para baixo para tentar de novo. Seus '
                      'registros continuam salvos no aparelho.',
                ),
              ),
              data: (day) => LiveJourney(
                day: day,
                now: ref.read(clockProvider).now,
                targetMinutes: targetMinutes,
                builder: (context, progress) => _TodayBody(
                  day: day,
                  progress: progress,
                  busy: _busy,
                  error: _error,
                  onRegister: () => _register(today),
                  onReview: _review,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Corpo da tela Hoje.
///
/// Fica separado para que o contador vivo reconstrua só esta subárvore e para
/// manter o `build` do estado legível.
class _TodayBody extends StatelessWidget {
  const _TodayBody({
    required this.day,
    required this.progress,
    required this.busy,
    required this.error,
    required this.onRegister,
    required this.onReview,
  });

  final WorkDaySummary day;
  final WorkdayProgress progress;
  final bool busy;
  final String? error;
  final VoidCallback onRegister;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final blocking = day.issues.where((issue) => issue.blocking).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TimeHero(progress: progress),
        const SizedBox(height: HfSpace.huge),
        if (error != null) ...[
          HfNotice(tone: HfNoticeTone.error, message: error!),
          const SizedBox(height: HfSpace.lg),
        ],
        // A pendência aparece onde ela acontece e já traz a saída.
        if (blocking.isNotEmpty) ...[
          HfNotice(
            title: blocking.length == 1
                ? 'Um registro precisa de atenção'
                : '${blocking.length} registros precisam de atenção',
            message: blocking.first.message,
            actionLabel: 'Corrigir horário',
            onAction: onReview,
          ),
          const SizedBox(height: HfSpace.lg),
        ],
        PunchButton(
          progress: progress,
          busy: busy,
          onPressed: progress.canRegister ? onRegister : null,
        ),
        HfSection(
          title: 'Jornada de hoje',
          trailing: TextButton(
            onPressed: onReview,
            child: const Text('Corrigir'),
          ),
          child: WorkdayTimeline(
            punches: day.punches,
            progress: progress,
            onEdit: (_) => onReview(),
          ),
        ),
        if (day.punches.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: HfSpace.sm),
            child: Text(
              'Registre a entrada para o OktaPonto começar a acompanhar o dia.',
              style: theme.textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}

/// Enquanto o dia carrega, a página mantém sua forma em vez de piscar um
/// indicador no meio da tela.
class _TodaySkeleton extends StatelessWidget {
  const _TodaySkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: HfSkeleton(
            height: HfSize.heroDial,
            width: HfSize.heroDial,
            borderRadius: HfRadius.hero,
          ),
        ),
        SizedBox(height: HfSpace.huge),
        HfSkeleton(height: HfSize.primaryAction, borderRadius: HfRadius.large),
        SizedBox(height: HfSpace.huge),
        HfSkeletonRow(),
        HfSkeletonRow(),
        HfSkeletonRow(),
        HfSkeletonRow(),
      ],
    );
  }
}
