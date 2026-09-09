import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Application-private filesystem operations.
///
/// Export creation is serialized inside the process and uses exclusive path
/// creation. This preserves the product contract that an existing export is never
/// overwritten, including when two export requests are triggered concurrently.
final class FileService {
  const FileService({this.documentsRootPath});

  final String? documentsRootPath;

  static Future<void> _writeTail = Future<void>.value();

  Future<T> _serialized<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    final previous = _writeTail;
    final gate = Completer<void>();
    _writeTail = gate.future;
    previous.whenComplete(() async {
      try {
        completer.complete(await action());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      } finally {
        gate.complete();
      }
    });
    return completer.future;
  }

  Future<String> exportDirectory() async {
    final root = documentsRootPath == null
        ? await getApplicationDocumentsDirectory()
        : Directory(documentsRootPath!);
    final directory = Directory(p.join(root.path, 'exports'));
    await directory.create(recursive: true);
    return directory.path;
  }

  /// Advisory filename lookup for display/tests. Production exports should use
  /// [writeUniqueAtomically], which performs selection and write under one
  /// process-wide critical section.
  Future<String> reserveUniqueName(String directory, String filename) async {
    final ext = p.extension(filename);
    final stem = p.basenameWithoutExtension(filename);
    var candidate = p.join(directory, filename);
    var suffix = 2;
    while (await File(candidate).exists()) {
      candidate = p.join(directory, '${stem}_$suffix$ext');
      suffix++;
    }
    return candidate;
  }

  /// Writes a brand-new file and fails instead of replacing an existing path.
  /// A failed write removes only the incomplete new file; older exports remain
  /// untouched.
  Future<void> writeAtomically(String targetPath, List<int> bytes) {
    return _serialized(() => _writeExclusive(targetPath, bytes));
  }

  Future<void> _writeExclusive(String targetPath, List<int> bytes) async {
    final parent = Directory(p.dirname(targetPath));
    await parent.create(recursive: true);
    final target = File(targetPath);
    RandomAccessFile? handle;
    var createdByThisCall = false;
    try {
      // create(exclusive: true) is the atomic no-overwrite primitive exposed by
      // dart:io. Only after owning the new path do we open and fill it.
      await target.create(exclusive: true);
      createdByThisCall = true;
      handle = await target.open(mode: FileMode.write);
      await handle.writeFrom(bytes);
      await handle.flush();
      await handle.close();
      handle = null;
    } catch (_) {
      if (handle != null) {
        try {
          await handle.close();
        } catch (_) {}
      }
      if (createdByThisCall && await target.exists()) {
        try {
          await target.delete();
        } catch (_) {}
      }
      if (!createdByThisCall && await target.exists()) {
        throw StateError('Arquivo de destino já existe: $targetPath');
      }
      rethrow;
    }
  }

  /// Selects a unique suffix and creates the export without an overwrite race.
  Future<String> writeUniqueAtomically(
    String directory,
    String filename,
    List<int> bytes,
  ) {
    return _serialized(() async {
      await Directory(directory).create(recursive: true);
      final ext = p.extension(filename);
      final stem = p.basenameWithoutExtension(filename);
      var suffix = 1;
      while (true) {
        final candidate = p.join(
          directory,
          suffix == 1 ? filename : '${stem}_${suffix + 1}$ext',
        );
        try {
          await _writeExclusive(candidate, bytes);
          return candidate;
        } on StateError {
          if (!await File(candidate).exists()) rethrow;
          suffix++;
        } on FileSystemException {
          if (!await File(candidate).exists()) rethrow;
          suffix++;
        }
      }
    });
  }

  Future<void> clearExports() async {
    final directory = Directory(await exportDirectory());
    if (!await directory.exists()) return;
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is File) {
        await entity.delete();
      } else if (entity is Directory) {
        await entity.delete(recursive: true);
      }
    }
  }
}
