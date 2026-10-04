import 'dart:collection';

import 'package:denial_flutter_sdk/models.dart';

/// Input-routing partitions of one immutable layer-surface snapshot.
/// Each partition retains the original order, which determines stacking.
final class DesktopInputSurfaceIndex {
  factory DesktopInputSurfaceIndex(List<DenialWindow> source) {
    final positioned = <DenialWindow>[];
    final background = <DenialWindow>[];
    final foreground = <DenialWindow>[];
    for (final surface in source) {
      if (surface.geometry == null) continue;
      positioned.add(surface);
      switch (surface.contentKind) {
        case DenialWindowContentKind.layerShellBackground ||
            DenialWindowContentKind.layerShellBottom:
          background.add(surface);
        case DenialWindowContentKind.layerShellTop ||
            DenialWindowContentKind.layerShellOverlay:
          foreground.add(surface);
        default:
          break;
      }
    }
    return DesktopInputSurfaceIndex._(
      source,
      UnmodifiableListView(positioned),
      UnmodifiableListView(background),
      UnmodifiableListView(foreground),
    );
  }

  const DesktopInputSurfaceIndex._(
    this.source,
    this.positioned,
    this.background,
    this.foreground,
  );

  final List<DenialWindow> source;
  final List<DenialWindow> positioned;
  final List<DenialWindow> background;
  final List<DenialWindow> foreground;
}
