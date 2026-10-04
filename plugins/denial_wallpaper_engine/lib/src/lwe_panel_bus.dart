import 'dart:async';

/// In-process event bridge between [ShellAction] handlers (which have no
/// Riverpod access) and the panel surface mounted in the desktop scene.
///
/// Both live in the same Flutter isolate of the shell bundle, so a broadcast
/// stream is enough. No state lives here — the panel surface owns visibility.
class LwePanelBus {
  LwePanelBus._();

  static final LwePanelBus instance = LwePanelBus._();

  final _controller = StreamController<LwePanelEvent>.broadcast();

  Stream<LwePanelEvent> get events => _controller.stream;

  void togglePanel() => _controller.add(LwePanelEvent.toggle);

  void requestRandom() => _controller.add(LwePanelEvent.random);

  void closePanel() => _controller.add(LwePanelEvent.close);

  void dispose() {
    _controller.close();
  }
}

enum LwePanelEvent { toggle, random, close }