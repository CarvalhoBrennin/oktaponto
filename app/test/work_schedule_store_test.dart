import 'package:flutter_test/flutter_test.dart';
import 'package:oktaponto/features/schedule/data/work_schedule_store.dart';
import 'package:oktaponto/features/schedule/domain/work_schedule.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const store = PrefsWorkScheduleStore();

  test('aparelho novo não tem jornada nem apresentação vista', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final setup = await store.load();
    expect(setup.onboardingSeen, isFalse);
    expect(setup.schedule, isNull);
    expect(setup.needsOnboarding, isTrue);
  });

  test('salvar grava a jornada e encerra a apresentação', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final schedule = WorkSchedule.defaults.copyWith(
      startMinuteOfDay: 7 * 60,
      breakMode: BreakMode.flexible,
      breakMinutes: 90,
    );
    await store.save(schedule);
    await store.markOnboardingSeen();

    final setup = await store.load();
    expect(setup.onboardingSeen, isTrue);
    expect(setup.schedule, schedule);
    expect(setup.targetMinutes, schedule.targetMinutes);
  });

  test('pular deixa a apresentação vista sem jornada', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await store.markOnboardingSeen();
    final setup = await store.load();
    expect(setup.needsOnboarding, isFalse);
    expect(setup.schedule, isNull);
    expect(setup.targetMinutes, isNull);
  });

  test('jornada corrompida não impede a abertura do app', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'oktaponto_onboarding_seen': true,
      'oktaponto_work_schedule': 'isto não é json',
    });
    final setup = await store.load();
    expect(setup.onboardingSeen, isTrue);
    expect(setup.schedule, isNull);
  });

  test('limpar devolve o aparelho ao estado de primeira abertura', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await store.save(WorkSchedule.defaults);
    await store.markOnboardingSeen();
    await store.clear();

    final setup = await store.load();
    expect(setup.needsOnboarding, isTrue);
    expect(setup.schedule, isNull);
  });
}
