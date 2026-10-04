import 'package:flutter/material.dart';

class DesktopPanelEdgeTrigger extends StatelessWidget {
  const DesktopPanelEdgeTrigger({
    super.key,
    required this.onEnter,
    required this.onExit,
  });

  final VoidCallback onEnter;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: MouseRegion(
        opaque: true,
        onEnter: (_) => onEnter(),
        onExit: (_) => onExit(),
        child: const SizedBox.expand(),
      ),
    );
  }
}

Offset desktopPanelEntryDirection(int horizontal, int vertical) {
  if (horizontal != 0) {
    return Offset(horizontal.toDouble(), 0);
  }
  if (vertical != 0) {
    return Offset(0, vertical.toDouble());
  }
  return Offset.zero;
}
