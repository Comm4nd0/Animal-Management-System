// ignore: avoid_web_libraries_in_flutter
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Triggers a browser download of [content] as [filename].
/// Returns the filename (no real path on web).
Future<String> downloadFile(String content, String filename) async {
  final bytes = utf8.encode(content);
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
  return filename;
}

/// On web, triggers another download (share not available).
Future<void> shareFile(String filePath, {String? subject}) async {
  // On web, the file was already downloaded by downloadFile.
  // No-op since browser handles sharing via its own UI.
}

/// Not used on web (file_picker provides bytes directly).
Future<String> readFileContent(String path) async {
  return '';
}

/// Reads file bytes and returns as a UTF-8 string.
String bytesToString(List<int> bytes) {
  return utf8.decode(bytes);
}
