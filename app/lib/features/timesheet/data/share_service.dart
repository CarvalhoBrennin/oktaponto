import 'package:share_plus/share_plus.dart';

abstract interface class FileShareService {
  Future<void> shareXlsx(
    String filePath, {
    required String subject,
    required String text,
  });
}

final class NativeFileShareService implements FileShareService {
  const NativeFileShareService();

  @override
  Future<void> shareXlsx(
    String filePath, {
    required String subject,
    required String text,
  }) async {
    await SharePlus.instance.share(
      ShareParams(subject: subject, text: text, files: [XFile(filePath)]),
    );
  }
}
