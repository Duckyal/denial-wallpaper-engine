import 'package:denial_flutter_sdk/input.dart';
import 'package:denial_flutter_sdk/models.dart';
import 'package:denial_flutter_sdk/rendering.dart';
import 'package:flutter/material.dart';

import 'desktop_pixel_alignment.dart';

class DesktopLayerShellSurface extends StatelessWidget {
  const DesktopLayerShellSurface({
    required this.surface,
    required this.displayLayout,
    super.key,
  });

  final DenialWindow surface;
  final DisplayLayout? displayLayout;

  @override
  Widget build(BuildContext context) {
    final geometry = surface.geometry;
    if (geometry == null || surface.surfaceLayers.isEmpty) {
      return const SizedBox.shrink();
    }
    final outputPixelGrid = desktopOutputPixelGridForMonitor(
      displayLayout,
      surface.monitorId,
    );
    return Positioned.fromRect(
      rect: geometry,
      // Flutter paints the client texture, while DesktopInputLayoutPublisher
      // transfers pointer and touch ownership to the native Wayland route.
      // Keeping this widget transparent avoids duplicating that lifecycle in
      // Flutter's gesture arena.
      child: IgnorePointer(
        child: RepaintBoundary(
          child: WindowSurfaceTree(
            window: surface,
            includePopups: true,
            presentationScale: outputPixelGrid?.scale,
            pixelGridOrigin:
                outputPixelGrid?.logicalRect.topLeft ?? Offset.zero,
          ),
        ),
      ),
    );
  }
}

/// Owns overview input while keeping wallpaper-plane controls interactive.
///
/// The full-scene region transfers native pointer ownership to Flutter. The
/// dismissal barrier then handles otherwise-unclaimed taps, while controls
/// painted after it (such as the workspace indicator and system tray) win
/// Flutter hit testing inside their own bounds.
class DesktopOverviewInputLayer extends StatelessWidget {
  const DesktopOverviewInputLayer({
    required this.active,
    required this.onBarrierTap,
    required this.foregroundControls,
    super.key,
  });

  final bool active;
  final ValueChanged<Offset> onBarrierTap;
  final List<Widget> foregroundControls;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Positioned.fill(
          child: ShellInputRegion(
            debugLabel: 'Desktop overview',
            active: active,
            pointerPolicy: ShellPointerPolicy.fullScene,
            keyboardPolicy: ShellKeyboardPolicy.capture,
            compositorPolicy: ShellCompositorPolicy.exclusive,
            child: const IgnorePointer(child: SizedBox.expand()),
          ),
        ),
        Positioned.fill(
          child: _DesktopOverviewBarrier(active: active, onTap: onBarrierTap),
        ),
        ...foregroundControls,
      ],
    );
  }
}

class _DesktopOverviewBarrier extends StatelessWidget {
  const _DesktopOverviewBarrier({required this.active, required this.onTap});

  final bool active;
  final ValueChanged<Offset> onTap;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !active,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (details) => onTap(details.localPosition),
      ),
    );
  }
}
