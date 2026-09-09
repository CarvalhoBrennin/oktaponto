import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

final class FileService {
  const FileService();

  Future<String> exportDirectory() async {
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory(p.join(root.path, 'exports'));
    await directory.create(recursive: true);
    return directory.path;
  }

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

  Future<void> writeAtomically(String targetPath, List<int> bytes) async {
    final parent = Directory(p.dirname(targetPath));
    await parent.create(recursive: true);
    final random = Random.secure().nextInt(1 << 31);
    final temp = File('$targetPath.tmp.$random');
    try {
      await temp.writeAsBytes(bytes, flush: true);
      if (await File(targetPath).exists()) {
        throw StateError('Arquivo de destino já existe: $targetPath');
      }
      await temp.rename(targetPath);
    } catch (_) {
      if (await temp.exists()) {
        await temp.delete();
      }
      rethrow;
    }
  }
}
