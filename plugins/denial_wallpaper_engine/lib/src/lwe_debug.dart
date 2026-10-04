import 'dart:async';
import 'dart:io';

const _maxLogSize = 5 * 1024 * 1024;

IOSink? _sink;
bool _initialized = false;

Future<void> _init() async {
  if (_initialized) return;
  _initialized = true;
  for (final path in ['/tmp/lwe-debug.log', _homeCacheLog()]) {
    try {
      final file = File(path);
      if (file.existsSync() && file.lengthSync() > _maxLogSize) {
        file.writeAsStringSync('');
      }
      _sink = file.openWrite(mode: FileMode.append);
      return;
    } on Object {
      // Try the next location; diagnostics must never break the wallpaper.
    }
  }
}

void lweLog(String message) {
  final line = '${DateTime.now().toIso8601String()} $message\n';
  _init().then((_) {
    _sink?.write(line);
  });
}

String _homeCacheLog() {
  final home = Platform.environment['HOME'] ?? '/tmp';
  return '$home/.cache/lwe-debug.log';
}