/// Null workspace means workspaces are disabled on the requesting desktop.
typedef WindowEmphasisTarget = ({
  int windowId,
  int monitorId,
  int? workspaceId,
});

bool windowIsDeemphasized(
  WindowEmphasisTarget? target, {
  required int windowId,
  required int monitorId,
  required int workspaceId,
  required bool pinned,
}) =>
    target != null &&
    windowId != target.windowId &&
    monitorId == target.monitorId &&
    (target.workspaceId == null || pinned || workspaceId == target.workspaceId);

/// Only the most recent owner can release a temporary window emphasis.
/// This prevents a departing preview from clearing a newer preview's request.
class WindowEmphasisRequests {
  WindowEmphasisRequests(this.onChanged);

  final void Function(WindowEmphasisTarget?) onChanged;
  Object? _owner;
  WindowEmphasisTarget? _target;

  WindowEmphasisTarget? get target => _target;

  void Function() begin(WindowEmphasisTarget target) {
    final owner = Object();
    _owner = owner;
    _setTarget(target);
    return () {
      if (identical(_owner, owner)) clear();
    };
  }

  void clear() {
    _owner = null;
    _setTarget(null);
  }

  void _setTarget(WindowEmphasisTarget? value) {
    if (_target == value) return;
    _target = value;
    onChanged(value);
  }
}
