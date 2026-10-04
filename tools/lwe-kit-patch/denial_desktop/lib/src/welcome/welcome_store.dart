import 'dart:io';

/// Deliberately separate from settings: resetting appearance must not reopen
/// onboarding. The native --autostart gate uses the same XDG config path.
class WelcomeStore {
  WelcomeStore({Map<String, String>? environment}) {
    final env = environment ?? Platform.environment;
    final config = env['XDG_CONFIG_HOME'];
    final root = config != null && config.startsWith('/')
        ? config
        : '${env['HOME']}/.config';
    completed = File('$root/denial/welcome');
    final state = env['XDG_STATE_HOME'];
    final legacyRoot = state != null && state.startsWith('/')
        ? state
        : '${env['HOME']}/.local/state';
    _legacyCompleted = File('$legacyRoot/denial/welcome-completed');
  }

  late final File completed;
  late final File _legacyCompleted;

  Future<void> complete() async {
    await completed.parent.create(recursive: true);
    final temporary = File('${completed.path}.$pid.tmp');
    try {
      await temporary.writeAsString('1\n', flush: true);
      await temporary.rename(completed.path);
      // Once the new marker is durable, the first version's marker no longer
      // needs to participate in startup. Removing the new marker can reset setup.
      if (await _legacyCompleted.exists()) await _legacyCompleted.delete();
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }
}
