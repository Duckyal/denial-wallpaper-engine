import 'package:denial_flutter_sdk/models.dart';
import 'package:flutter/foundation.dart';

import 'desktop_workspace.dart';

class DesktopSceneWindows {
  // Structural scene invalidation deliberately excludes window titles. During
  // a native grab it also excludes live buffer geometry for the grabbed
  // windows. Each keyed frame and popup layer selects its own current window.
  DesktopSceneWindows(
    List<DenialWindow> windows,
    Set<int> livePlacementObjectIds,
  ) : windows = List<DenialWindow>.unmodifiable(
        windows.where((window) => window.isUserApp || window.isPopupSurface),
      ),
      livePlacementObjectIds = Set.unmodifiable(livePlacementObjectIds);

  final List<DenialWindow> windows;
  final Set<int> livePlacementObjectIds;

  @override
  bool operator ==(Object other) {
    if (other is! DesktopSceneWindows ||
        !setEquals(other.livePlacementObjectIds, livePlacementObjectIds) ||
        other.windows.length != windows.length) {
      return false;
    }
    for (var index = 0; index < windows.length; index += 1) {
      final window = windows[index];
      final otherWindow = other.windows[index];
      final livePlacement =
          livePlacementObjectIds.contains(window.objectId) &&
          other.livePlacementObjectIds.contains(otherWindow.objectId);
      if (livePlacement
          ? !window.hasSameStaticSceneRoleAs(otherWindow)
          : !window.hasSameSceneDescriptionAs(otherWindow)) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => runtimeType.hashCode;
}

class DesktopSceneWorkspace {
  const DesktopSceneWorkspace(this.state);

  final DesktopWorkspaceState state;

  @override
  bool operator ==(Object other) {
    return other is DesktopSceneWorkspace &&
        desktopWorkspaceHasSameSceneStructure(state, other.state);
  }

  @override
  int get hashCode => Object.hash(
    state.nextZ,
    state.viewSize,
    identityHashCode(state.overview),
    state.placements.length,
  );
}
