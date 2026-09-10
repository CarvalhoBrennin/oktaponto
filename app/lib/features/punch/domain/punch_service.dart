import 'package:clock/clock.dart';

import '../../../core/time/time_utils.dart';
import '../../../core/validation/punch_sequence_validator.dart';
import 'models.dart';
import 'repositories.dart';

abstract interface class PunchService {
  Future<Punch> registerNextPunch(DateTime localDate);
  Future<Punch> addManualPunch(DateTime localDate, DateTime localTime);
  Future<void> editPunch(PunchEdit edit);
  Future<void> deletePunch(int punchId, DateTime localDate);
}

final class DefaultPunchService implements PunchService {
  DefaultPunchService({
    required this.repository,
    Clock? timeClock,
    this.sequenceValidator = const PunchSequenceValidator(),
  }) : timeClock = timeClock ?? Clock();

  final PunchRepository repository;
  final Clock timeClock;
  final PunchSequenceValidator sequenceValidator;

  bool _registrationInFlight = false;

  @override
  Future<Punch> registerNextPunch(DateTime localDate) async {
    if (_registrationInFlight) {
      throw StateError('Um registro de ponto já está em andamento.');
    }
    _registrationInFlight = true;
    try {
      final nowLocal = timeClock.now();
      if (localDateKey(nowLocal) != localDateKey(localDate)) {
        throw StateError(
          'Jornada cruzando meia-noite não é inferida automaticamente no MVP.',
        );
      }
      return await repository.transaction((transactionalRepository) async {
        final punches = await transactionalRepository.listDay(localDate);
        final issues = sequenceValidator.validate(punches);
        if (issues.any((issue) => issue.blocking)) {
          throw StateError(
            'O dia possui inconsistências e precisa ser corrigido antes de nova batida.',
          );
        }
        if (punches.length >= 4) {
          throw StateError(
            'O dia já possui quatro batidas. Edite o histórico para corrigir.',
          );
        }
        final kind = punches.length.isEven ? PunchKind.in_ : PunchKind.out;
        final draft = PunchDraft(
          localDate: localDateKey(localDate),
          occurredAtUtc: nowLocal.toUtc(),
          utcOffsetMinutes: nowLocal.timeZoneOffset.inMinutes,
          kind: kind,
        );
        final candidate = <Punch>[
          ...punches,
          Punch(
            id: -1,
            occurredAtUtc: draft.occurredAtUtc,
            localDate: draft.localDate,
            utcOffsetMinutes: draft.utcOffsetMinutes,
            kind: draft.kind,
            isEdited: false,
          ),
        ];
        final candidateIssues = sequenceValidator.validate(candidate);
        if (candidateIssues.any((issue) => issue.blocking)) {
          throw StateError(candidateIssues.first.message);
        }
        return transactionalRepository.insert(draft);
      });
    } finally {
      _registrationInFlight = false;
    }
  }

  @override
  Future<Punch> addManualPunch(DateTime localDate, DateTime localTime) {
    return repository.transaction((transactionalRepository) async {
      final punches = await transactionalRepository.listDay(localDate);
      if (punches.length >= 4) {
        throw StateError('O dia já possui quatro batidas.');
      }
      final normalizedLocal = DateTime(
        localDate.year,
        localDate.month,
        localDate.day,
        localTime.hour,
        localTime.minute,
        localTime.second,
        localTime.millisecond,
        localTime.microsecond,
      );
      // Use the offset at the manually selected wall-clock instant. Reusing
      // the first punch offset can be wrong on daylight-saving transitions.
      final offsetMinutes = normalizedLocal.timeZoneOffset.inMinutes;
      final occurredAtUtc = wallClockToUtc(normalizedLocal, offsetMinutes);
      final insertionIndex = punches
          .where((punch) => punch.occurredAtUtc.isBefore(occurredAtUtc))
          .length;
      final kind = insertionIndex.isEven ? PunchKind.in_ : PunchKind.out;
      final draft = PunchDraft(
        localDate: localDateKey(localDate),
        occurredAtUtc: occurredAtUtc,
        utcOffsetMinutes: offsetMinutes,
        kind: kind,
        isEdited: true,
      );
      final candidate = Punch(
        id: -1,
        occurredAtUtc: draft.occurredAtUtc,
        localDate: draft.localDate,
        utcOffsetMinutes: draft.utcOffsetMinutes,
        kind: draft.kind,
        isEdited: true,
      );
      final next = [...punches, candidate]
        ..sort((a, b) => a.occurredAtUtc.compareTo(b.occurredAtUtc));
      final issues = sequenceValidator.validate(next);
      if (issues.any((issue) => issue.blocking)) {
        throw StateError(issues.first.message);
      }
      return transactionalRepository.insert(draft);
    });
  }

  @override
  Future<void> editPunch(PunchEdit edit) {
    return repository.transaction((transactionalRepository) async {
      final date = parseLocalDate(edit.localDate);
      final punches = await transactionalRepository.listDay(date);
      if (!punches.any((punch) => punch.id == edit.id)) {
        throw StateError(
          'A batida não pertence ao dia informado. Mover batidas entre dias não é suportado.',
        );
      }
      final replacement = Punch(
        id: edit.id,
        occurredAtUtc: edit.occurredAtUtc,
        localDate: edit.localDate,
        utcOffsetMinutes: edit.utcOffsetMinutes,
        kind: edit.kind,
        isEdited: true,
      );
      if (localDateKey(replacement.occurredAtLocal) != edit.localDate) {
        throw StateError(
          'O horário corrigido cai em outra data local. Jornadas overnight exigem revisão explícita.',
        );
      }
      final candidate =
          punches
              .map((punch) => punch.id == edit.id ? replacement : punch)
              .toList()
            ..sort((a, b) => a.occurredAtUtc.compareTo(b.occurredAtUtc));
      final issues = sequenceValidator.validate(candidate);
      if (issues.any((issue) => issue.blocking)) {
        throw StateError(issues.first.message);
      }
      await transactionalRepository.update(edit);
    });
  }

  @override
  Future<void> deletePunch(int punchId, DateTime localDate) {
    return repository.transaction((transactionalRepository) async {
      final punches = await transactionalRepository.listDay(localDate);
      if (!punches.any((punch) => punch.id == punchId)) {
        throw StateError('Batida não encontrada.');
      }
      await transactionalRepository.softDelete(punchId);
    });
  }
}
