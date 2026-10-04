import 'package:flutter/material.dart';

import 'package:denial_flutter_sdk/tokens.dart';

class HomeBackdropPainter extends CustomPainter {
  const HomeBackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final scrim = Paint()..color = ShellMediaColors.wallpaperScrim;
    canvas.drawRect(Offset.zero & size, scrim);
  }

  @override
  bool shouldRepaint(covariant HomeBackdropPainter oldDelegate) {
    return false;
  }
}
