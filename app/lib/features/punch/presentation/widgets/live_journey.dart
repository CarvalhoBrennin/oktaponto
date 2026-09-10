import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../domain/models.dart';
import '../../domain/workday_progress.dart';

/// Mantém a leitura da jornada em dia com o relógio.
///
/// Enquanto houver um período aberto, reconstrói apenas esta subárvore a cada
/// [_tick] — o resto da tela não é reconstruído por causa do contador. Quando
/// o dia está encerrado, não iniciado ou é um dia passado, nenhum timer roda.
class LiveJourney extends StatefulWidget {
  const LiveJourney({
    super.key,
    required this.day,
    required this.now,
    required this.targetMinutes,
    required this.builder,
  });

  final WorkDaySummary day;

  /// Relógio injetado (vem do `clockProvider`), para que testes fixem o tempo.
  final DateTime Function() now;

  /// Meta do dia vinda da jornada configurada, ou `null` sem jornada.
  final int? targetMinutes;

  final Widget Function(BuildContext context, WorkdayProgress progress) builder;

  @override
  State<LiveJourney> createState() => _LiveJourneyState();
}

class _LiveJourneyState extends State<LiveJourney> {
  // O contador mostra minutos: meio minuto de resolução é suficiente e mantém
  // o custo perto de zero.
  static const _tick = Duration(seconds: 30);

  Timer? _timer;
  late WorkdayProgress _progress;

  @override
  void initState() {
    super.initState();
    _recompute();
  }

  @override
  void didUpdateWidget(LiveJourney oldWidget) {
    super.didUpdateWidget(oldWidget);
    _recompute();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _recompute() {
    _progress = describeWorkday(
      widget.day,
      widget.now(),
      targetMinutes: widget.targetMinutes,
    );
    if (_progress.isLive) {
      _timer ??= Timer.periodic(_tick, (_) {
        if (!mounted) return;
        setState(_recompute);
      });
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _progress);
}
