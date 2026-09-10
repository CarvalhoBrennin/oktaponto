import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oktaponto/core/theme/app_theme.dart';
import 'package:oktaponto/features/punch/domain/models.dart';
import 'package:oktaponto/features/punch/domain/work_hours_calculator.dart';
import 'package:oktaponto/features/punch/domain/workday_progress.dart';
import 'package:oktaponto/features/punch/presentation/widgets/punch_button.dart';

const _calculator = DefaultWorkHoursCalculator();

Punch _punch(int id, DateTime localTime, PunchKind kind) => Punch(
  id: id,
  occurredAtUtc: DateTime.utc(
    localTime.year,
    localTime.month,
    localTime.day,
    localTime.hour,
    localTime.minute,
  ),
  localDate: '2026-09-01',
  utcOffsetMinutes: 0,
  kind: kind,
  isEdited: false,
);

WorkDaySummary _day(List<Punch> punches) => _calculator.calculate(
  DateTime(2026, 9, 1),
  punches,
  const WorkDayMetadata(localDate: '2026-09-01'),
);

void main() {
  final entry = _punch(1, DateTime(2026, 9, 1, 8), PunchKind.in_);
  final breakStart = _punch(2, DateTime(2026, 9, 1, 12), PunchKind.out);
  final breakEnd = _punch(3, DateTime(2026, 9, 1, 13), PunchKind.in_);
  final exit = _punch(4, DateTime(2026, 9, 1, 17), PunchKind.out);

  test('dia sem batidas ainda não começou', () {
    final progress = describeWorkday(
      _day(const []),
      DateTime.utc(2026, 9, 1, 7),
    );
    expect(progress.phase, WorkdayPhase.notStarted);
    expect(progress.displayedMinutes, 0);
    expect(progress.nextStep, PunchStep.entry);
    expect(progress.isLive, isFalse);
  });

  test('trabalhando soma o período aberto apenas para exibição', () {
    final day = _day([entry]);
    final progress = describeWorkday(day, DateTime.utc(2026, 9, 1, 10, 30));
    expect(progress.phase, WorkdayPhase.working);
    // O total autoritativo do domínio continua zero: nenhum par fechou.
    expect(day.workedMinutes, 0);
    expect(progress.closedMinutes, 0);
    expect(progress.runningWorkedMinutes, 150);
    expect(progress.displayedMinutes, 150);
    expect(progress.nextStep, PunchStep.breakStart);
    expect(progress.isLive, isTrue);
  });

  test('intervalo não acrescenta minutos trabalhados', () {
    final progress = describeWorkday(
      _day([entry, breakStart]),
      DateTime.utc(2026, 9, 1, 12, 40),
    );
    expect(progress.phase, WorkdayPhase.onBreak);
    expect(progress.closedMinutes, 240);
    expect(progress.runningWorkedMinutes, 0);
    expect(progress.displayedMinutes, 240);
    expect(progress.nextStep, PunchStep.breakEnd);
  });

  test('segundo período soma sobre o primeiro', () {
    final progress = describeWorkday(
      _day([entry, breakStart, breakEnd]),
      DateTime.utc(2026, 9, 1, 15),
    );
    expect(progress.phase, WorkdayPhase.working);
    expect(progress.closedMinutes, 240);
    expect(progress.runningWorkedMinutes, 120);
    expect(progress.displayedMinutes, 360);
    expect(progress.nextStep, PunchStep.exit);
  });

  test('jornada completa encerra e não corre mais', () {
    final progress = describeWorkday(
      _day([entry, breakStart, breakEnd, exit]),
      DateTime.utc(2026, 9, 1, 19),
    );
    expect(progress.phase, WorkdayPhase.finished);
    expect(progress.displayedMinutes, 480);
    expect(progress.nextStep, isNull);
    expect(progress.canRegister, isFalse);
    expect(progress.isLive, isFalse);
  });

  test('um dia passado com período aberto não conta tempo vivo', () {
    final progress = describeWorkday(
      _day([entry]),
      DateTime.utc(2026, 9, 4, 10),
    );
    expect(progress.phase, WorkdayPhase.working);
    expect(progress.isLive, isFalse);
    expect(progress.runningWorkedMinutes, 0);
    expect(progress.displayedMinutes, 0);
  });

  test('relógio atrasado nunca produz tempo negativo', () {
    final progress = describeWorkday(
      _day([entry]),
      DateTime.utc(2026, 9, 1, 7),
    );
    expect(progress.runningWorkedMinutes, 0);
  });

  test('contador usa o instante real, não o horário de parede da batida', () {
    // Batida das 08:00 em UTC-3, ou seja, 11:00 UTC. Uma hora depois, o
    // contador precisa dizer 60 minutos — e não 240, que é o que sairia de
    // comparar `occurredAtLocal` (08:00 com flag UTC) contra o agora em UTC.
    final punch = Punch(
      id: 1,
      occurredAtUtc: DateTime.utc(2026, 9, 1, 11),
      localDate: '2026-09-01',
      utcOffsetMinutes: -180,
      kind: PunchKind.in_,
      isEdited: false,
    );
    final day = _calculator.calculate(DateTime(2026, 9, 1), [
      punch,
    ], const WorkDayMetadata(localDate: '2026-09-01'));
    final progress = describeWorkday(day, DateTime.utc(2026, 9, 1, 12));
    expect(progress.phaseSince!.hour, 8, reason: 'exibe o horário local');
    expect(progress.runningWorkedMinutes, 60);
  });

  test('dia inconsistente pede revisão e bloqueia o registro', () {
    final invalid = _day([_punch(1, DateTime(2026, 9, 1, 8), PunchKind.out)]);
    final progress = describeWorkday(invalid, DateTime.utc(2026, 9, 1, 9));
    expect(progress.phase, WorkdayPhase.needsReview);
    expect(progress.nextStep, isNull);
    expect(progress.canRegister, isFalse);
  });

  testWidgets('dia inconsistente mostra estado de correção em vez de quebrar', (
    tester,
  ) async {
    // Cenário real: o usuário apaga a entrada e sobra uma saída solta. Antes,
    // o CTA tentava desenhar o ícone do próximo passo e derrubava a tela.
    final day = const DefaultWorkHoursCalculator().calculate(
      DateTime(2026, 9, 1),
      [_punch(2, DateTime(2026, 9, 1, 12), PunchKind.out)],
      const WorkDayMetadata(localDate: '2026-09-01'),
    );
    expect(day.status, WorkDayStatus.invalid);
    final progress = describeWorkday(day, DateTime.utc(2026, 9, 1, 13));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: PunchButton(progress: progress, onPressed: null, busy: false),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Corrija o dia para continuar'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
  });

  group('meta do dia', () {
    test('sem meta configurada não há quanto falta', () {
      final progress = describeWorkday(
        _day([entry, breakStart]),
        DateTime.utc(2026, 9, 1, 12, 30),
      );
      expect(progress.targetMinutes, isNull);
      expect(progress.remainingMinutes, isNull);
      expect(progress.goalFraction, isNull);
      expect(progress.reachedGoal, isFalse);
    });

    test('com meta, o que falta desconta o tempo já corrido', () {
      final progress = describeWorkday(
        _day([entry, breakStart, breakEnd]),
        DateTime.utc(2026, 9, 1, 15),
        targetMinutes: 480,
      );
      // 4h fechadas + 2h em curso.
      expect(progress.displayedMinutes, 360);
      expect(progress.remainingMinutes, 120);
      expect(progress.goalFraction, closeTo(0.75, 0.0001));
      expect(progress.reachedGoal, isFalse);
    });

    test('passar da meta não estoura a fração do anel', () {
      final progress = describeWorkday(
        _day([entry, breakStart, breakEnd, exit]),
        DateTime.utc(2026, 9, 1, 18),
        targetMinutes: 400,
      );
      expect(progress.displayedMinutes, 480);
      expect(progress.remainingMinutes, -80);
      expect(progress.goalFraction, 1.0);
      expect(progress.reachedGoal, isTrue);
    });
  });
}
