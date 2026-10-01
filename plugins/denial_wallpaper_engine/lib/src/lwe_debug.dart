import 'dart:io';

/// Temporary file-backed tracing for release builds where debugPrint output
/// is not observable. Remove once the startup path is verified.
void lweLog(String message) {
  final line = '${DateTime.now().toIso8601String()} $message\n';
  for (final path in ['/tmp/lwe-debug.log', _homeCacheLog()]) {
    try {
      File(path).writeAsStringSync(line, mode: FileMode.append);
      return;
    } on Object {
      // Try the next location; diagnostics must never break the wallpaper.
    }
  }
}

String _homeCacheLog() {
  final home = Platform.environment['HOME'] ?? '/tmp';
  return '$home/.cache/lwe-debug.log';
}
