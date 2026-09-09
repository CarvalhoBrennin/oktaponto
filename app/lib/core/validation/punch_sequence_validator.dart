import '../../features/punch/domain/models.dart';

final class PunchSequenceValidator {
  const PunchSequenceValidator();

  List<ValidationIssue> validate(List<Punch> punches) {
    if (punches.length > 4) {
      return const [
        ValidationIssue(
          'too_many_punches',
          'O MVP permite no máximo quatro batidas por dia.',
        ),
      ];
    }

    final issues = <ValidationIssue>[];
    for (var index = 0; index < punches.length; index++) {
      final expected = index.isEven ? PunchKind.in_ : PunchKind.out;
      if (punches[index].kind != expected) {
        issues.add(
          ValidationIssue(
            'invalid_kind_$index',
            index == 0
                ? 'A primeira batida do dia precisa ser uma entrada.'
                : 'A sequência de entrada e saída está inválida.',
          ),
        );
      }
      if (index > 0) {
        final previous =
            punches[index - 1].occurredAtUtc.millisecondsSinceEpoch;
        final current = punches[index].occurredAtUtc.millisecondsSinceEpoch;
        if (current <= previous) {
          issues.add(
            const ValidationIssue(
              'timestamps_not_strictly_increasing',
              'As batidas precisam estar em ordem estritamente crescente.',
            ),
          );
          break;
        }
      }
    }
    return issues;
  }
}
