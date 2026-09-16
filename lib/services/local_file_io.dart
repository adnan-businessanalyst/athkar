import 'dart:io';

import 'package:path_provider/path_provider.dart';

bool localFileExists(String path) => File(path).existsSync();

Future<String?> copyToDocuments(String sourcePath) async {
  final docs = await getApplicationDocumentsDirectory();
  final extension = sourcePath.split('.').last;
  final dest = File('${docs.path}/adhan.$extension');
  await File(sourcePath).copy(dest.path);
  return dest.path;
}
