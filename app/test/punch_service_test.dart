import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horafolio/features/punch/domain/models.dart';
import 'package:horafolio/features/punch/domain/punch_service.dart';
import 'package:horafolio/features/punch/domain/repositories.dart';

class FakePunchRepository implements PunchRepository {
  final items = <Punch>[];
  var _id = 1;
  Duration insertDelay = Duration.zero;

  @override
  Future<T> transaction<T>(
    Future<T> Function(PunchRepository repository) action,
  ) => action(this);

  @override
  Future<Punch> insert(PunchDraft draft) async {
    if (insertDelay > Duration.zero) await Future<void>.delayed(insertDelay);
    final item = Punch(
      id: _id++,
      occurredAtUtc: draft.occurredAtUtc,
      localDate: draft.localDate,
      utcOffsetMinutes: draft.utcOffsetMinutes,
      kind: draft.kind,
      isEdited: draft.isEdited,
    );
    items.add(item);
    return item;
  }

  @override
  Future<List<Punch>> listDay(DateTime localDate) async =>
      [...items]..sort((a, b) => a.occurredAtUtc.compareTo(b.occurredAtUtc));
  @override
  Future<void> softDelete(int punchId) async =>
      items.removeWhere((p) => p.id == punchId);
  @override
  Future<void> update(PunchEdit edit) async {
    final index = items.indexWhere((p) => p.id == edit.id);
    items[index] = items[index].copyWith(
      occurredAtUtc: edit.occurredAtUtc,
      localDate: edit.localDate,
      utcOffsetMinutes: edit.utcOffsetMinutes,
      kind: edit.kind,
      isEdited: true,
    );
  }

  @override
  Stream<List<Punch>> watchDay(DateTime localDate) => Stream.value(items);
  @override
  Stream<List<Punch>> watchMonth(int year, int month) => Stream.value(items);
  @override
  Future<void> clearAll() async => items.clear();
}

void main() {
  test('alternates IN OUT IN OUT and blocks fifth punch', () async {
    final repo = FakePunchRepository();
    final times = <DateTime>[
      DateTime(2026, 9, 1, 8),
      DateTime(2026, 9, 1, 12),
      DateTime(2026, 9, 1, 13),
      DateTime(2026, 9, 1, 17),
      DateTime(2026, 9, 1, 18),
    ];
    final service = DefaultPunchService(
      repository: repo,
      timeClock: Clock(() => times.removeAt(0)),
    );
    expect(
      (await service.registerNextPunch(DateTime(2026, 9, 1))).kind,
      PunchKind.in_,
    );
    expect(
      (await service.registerNextPunch(DateTime(2026, 9, 1))).kind,
      PunchKind.out,
    );
    expect(
      (await service.registerNextPunch(DateTime(2026, 9, 1))).kind,
      PunchKind.in_,
    );
    expect(
      (await service.registerNextPunch(DateTime(2026, 9, 1))).kind,
      PunchKind.out,
    );
    expect(
      () => service.registerNextPunch(DateTime(2026, 9, 1)),
      throwsStateError,
    );
  });

  test('rejects automatic punch when device time goes backwards', () async {
    final repo = FakePunchRepository();
    repo.items.add(
      Punch(
        id: 1,
        occurredAtUtc: DateTime.utc(2026, 9, 1, 12),
        localDate: '2026-09-01',
        utcOffsetMinutes: 0,
        kind: PunchKind.in_,
        isEdited: false,
      ),
    );
    final service = DefaultPunchService(
      repository: repo,
      timeClock: Clock.fixed(DateTime.utc(2026, 9, 1, 11)),
    );
    await expectLater(
      service.registerNextPunch(DateTime(2026, 9, 1)),
      throwsStateError,
    );
    expect(repo.items, hasLength(1));
  });

  test(
    'manual correction infers kind from chronological insertion position',
    () async {
      final repo = FakePunchRepository();
      repo.items.addAll([
        Punch(
          id: 1,
          occurredAtUtc: DateTime.utc(2026, 9, 1, 8),
          localDate: '2026-09-01',
          utcOffsetMinutes: 0,
          kind: PunchKind.in_,
          isEdited: false,
        ),
        Punch(
          id: 2,
          occurredAtUtc: DateTime.utc(2026, 9, 1, 12),
          localDate: '2026-09-01',
          utcOffsetMinutes: 0,
          kind: PunchKind.out,
          isEdited: false,
        ),
        Punch(
          id: 4,
          occurredAtUtc: DateTime.utc(2026, 9, 1, 17),
          localDate: '2026-09-01',
          utcOffsetMinutes: 0,
          kind: PunchKind.out,
          isEdited: false,
        ),
      ]);
      final service = DefaultPunchService(repository: repo);
      final inserted = await service.addManualPunch(
        DateTime(2026, 9, 1),
        DateTime(2026, 9, 1, 13),
      );
      expect(inserted.kind, PunchKind.in_);
      final ordered = await repo.listDay(DateTime(2026, 9, 1));
      expect(ordered.map((item) => item.kind), [
        PunchKind.in_,
        PunchKind.out,
        PunchKind.in_,
        PunchKind.out,
      ]);
    },
  );

  test('manual correction reuses the day captured UTC offset', () async {
    final repo = FakePunchRepository();
    repo.items.add(
      Punch(
        id: 1,
        occurredAtUtc: DateTime.utc(2026, 9, 1, 11),
        localDate: '2026-09-01',
        utcOffsetMinutes: -180,
        kind: PunchKind.in_,
        isEdited: false,
      ),
    );
    final service = DefaultPunchService(repository: repo);
    final inserted = await service.addManualPunch(
      DateTime(2026, 9, 1),
      DateTime(2026, 9, 1, 12),
    );
    expect(inserted.utcOffsetMinutes, -180);
    expect(inserted.occurredAtUtc, DateTime.utc(2026, 9, 1, 15));
  });

  test('editing into an impossible temporal sequence is rejected', () async {
    final repo = FakePunchRepository();
    repo.items.addAll([
      Punch(
        id: 1,
        occurredAtUtc: DateTime.utc(2026, 9, 1, 8),
        localDate: '2026-09-01',
        utcOffsetMinutes: 0,
        kind: PunchKind.in_,
        isEdited: false,
      ),
      Punch(
        id: 2,
        occurredAtUtc: DateTime.utc(2026, 9, 1, 12),
        localDate: '2026-09-01',
        utcOffsetMinutes: 0,
        kind: PunchKind.out,
        isEdited: false,
      ),
    ]);
    final service = DefaultPunchService(repository: repo);
    await expectLater(
      service.editPunch(
        PunchEdit(
          id: 1,
          localDate: '2026-09-01',
          occurredAtUtc: DateTime.utc(2026, 9, 1, 13),
          utcOffsetMinutes: 0,
          kind: PunchKind.in_,
        ),
      ),
      throwsStateError,
    );
  });

  test(
    'editing cannot make a punch reconstruct to another local date',
    () async {
      final repo = FakePunchRepository();
      repo.items.add(
        Punch(
          id: 1,
          occurredAtUtc: DateTime.utc(2026, 9, 1, 8),
          localDate: '2026-09-01',
          utcOffsetMinutes: 0,
          kind: PunchKind.in_,
          isEdited: false,
        ),
      );
      final service = DefaultPunchService(repository: repo);
      await expectLater(
        service.editPunch(
          PunchEdit(
            id: 1,
            localDate: '2026-09-01',
            occurredAtUtc: DateTime.utc(2026, 9, 2, 0, 30),
            utcOffsetMinutes: 0,
            kind: PunchKind.in_,
          ),
        ),
        throwsStateError,
      );
      expect(repo.items.single.occurredAtUtc, DateTime.utc(2026, 9, 1, 8));
    },
  );

  test('editing cannot move a punch to another work day', () async {
    final repo = FakePunchRepository();
    repo.items.add(
      Punch(
        id: 1,
        occurredAtUtc: DateTime.utc(2026, 9, 1, 8),
        localDate: '2026-09-01',
        utcOffsetMinutes: 0,
        kind: PunchKind.in_,
        isEdited: false,
      ),
    );
    final service = DefaultPunchService(repository: repo);
    await expectLater(
      service.editPunch(
        PunchEdit(
          id: 1,
          localDate: '2026-09-02',
          occurredAtUtc: DateTime.utc(2026, 9, 2, 8),
          utcOffsetMinutes: 0,
          kind: PunchKind.in_,
        ),
      ),
      throwsStateError,
    );
    expect(repo.items.single.localDate, '2026-09-01');
  });

  test('double submit is rejected while first insert is in flight', () async {
    final repo = FakePunchRepository()
      ..insertDelay = const Duration(milliseconds: 25);
    final service = DefaultPunchService(
      repository: repo,
      timeClock: Clock.fixed(DateTime(2026, 9, 1, 8)),
    );
    final first = service.registerNextPunch(DateTime(2026, 9, 1));
    await Future<void>.delayed(Duration.zero);
    await expectLater(
      service.registerNextPunch(DateTime(2026, 9, 1)),
      throwsStateError,
    );
    await first;
    expect(repo.items, hasLength(1));
  });
}
