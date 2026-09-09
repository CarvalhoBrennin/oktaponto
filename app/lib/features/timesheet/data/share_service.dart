import 'package:share_plus/share_plus.dart';

abstract interface class FileShareService {
  Future<void> shareXlsx(String filePath, {String? monthYear});
}

final class NativeFileShareService implements FileShareService {
  const NativeFileShareService();

  @override
  Future<void> shareXlsx(String filePath, {String? monthYear}) async {
    await SharePlus.instance.share(
      ShareParams(
        subject: monthYear == null ? 'Timesheet' : 'Timesheet - $monthYear',
        text: monthYear == null ? 'Timesheet' : 'Timesheet de $monthYear',
        files: [XFile(filePath)],
      ),
    );
  }
}
