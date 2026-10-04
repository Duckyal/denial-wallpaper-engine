import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:denial_flutter_sdk/shell_theme.dart';

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({this.path, this.bytes, this.size = 34, super.key});

  final String? path;
  final Uint8List? bytes;
  final double size;

  @override
  Widget build(BuildContext context) {
    final accent = ShellTheme.of(context).accentPalette;
    final fallback = Icon(
      Icons.person_rounded,
      size: size * .65,
      color: accent.onContainer,
    );
    final ImageProvider? image = bytes != null
        ? MemoryImage(bytes!)
        : path != null
        ? FileImage(File(path!))
        : null;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: accent.container,
          border: Border.all(color: context.shellColors.hairlineSoft),
        ),
        child: image == null
            ? fallback
            : Image(
                image: image,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback,
              ),
      ),
    );
  }
}
