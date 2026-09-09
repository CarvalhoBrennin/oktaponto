import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:horafolio/core/files/file_service.dart';

void main() {
  const service = FileService();

  test('reserveUniqueName never overwrites an existing export', () async {
    final dir = await Directory.systemTemp.createTemp('horafolio_files_');
    addTearDown(() => dir.delete(recursive: true));
    final first = File('${dir.path}/timesheet.xlsx');
    await first.writeAsBytes([1, 2, 3]);
    final next = await service.reserveUniqueName(dir.path, 'timesheet.xlsx');
    expect(next, endsWith('timesheet_2.xlsx'));
    expect(await first.readAsBytes(), [1, 2, 3]);
  });

  test(
    'atomic write fails closed if target appears and preserves it',
    () async {
      final dir = await Directory.systemTemp.createTemp('horafolio_atomic_');
      addTearDown(() => dir.delete(recursive: true));
      final target = File('${dir.path}/timesheet.xlsx');
      await target.writeAsBytes([9, 9, 9]);
      await expectLater(
        service.writeAtomically(target.path, [1, 2, 3]),
        throwsStateError,
      );
      expect(await target.readAsBytes(), [9, 9, 9]);
      expect(
        dir.listSync().whereType<File>().where(
          (file) => file.path.contains('.tmp.'),
        ),
        isEmpty,
      );
    },
  );
}
