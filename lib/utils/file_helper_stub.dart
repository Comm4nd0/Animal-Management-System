import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Triggers a file download (native: saves to documents directory).
/// Returns the saved file path.
Future<String> downloadFile(String content, String filename) async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsString(content);
  return file.path;
}

/// Shares a file. On native, uses share_plus.
Future<void> shareFile(String filePath, {String? subject}) async {
  await Share.shareXFiles(
    [XFile(filePath)],
    subject: subject,
  );
}

/// Reads the text content of a file at the given path.
Future<String> readFileContent(String path) async {
  return await File(path).readAsString();
}

/// Reads file bytes and returns as a UTF-8 string.
String bytesToString(List<int> bytes) {
  return utf8.decode(bytes);
}
