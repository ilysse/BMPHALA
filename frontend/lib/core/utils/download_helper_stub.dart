Future<void> downloadTextFile({
  required String filename,
  required String content,
  String mimeType = 'text/plain',
}) async {
  throw UnsupportedError('Downloads are available in the web build.');
}
