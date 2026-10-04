import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

typedef ProfileImagePicker = Future<String?> Function({
  required String title,
  required String cancelLabel,
  required String chooseLabel,
});

/// Decode once and retain a small, static PNG independent of the source file.
Future<Uint8List> prepareProfileImage(String path) async {
  final file = File(path);
  if (await file.length() > 16 * 1024 * 1024) {
    throw const FormatException('Profile image is too large');
  }
  final bytes = await file.readAsBytes();
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  try {
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    try {
      if (descriptor.width <= 0 ||
          descriptor.height <= 0 ||
          descriptor.width > 16384 ||
          descriptor.height > 16384 ||
          descriptor.width * descriptor.height > 40000000) {
        throw const FormatException('Unsupported image dimensions');
      }
      final scale = math.min(
        1.0,
        512 / math.max(descriptor.width, descriptor.height),
      );
      final codec = await descriptor.instantiateCodec(
        targetWidth: math.max(1, (descriptor.width * scale).round()),
        targetHeight: math.max(1, (descriptor.height * scale).round()),
      );
      try {
        final frame = await codec.getNextFrame();
        try {
          final png = await frame.image.toByteData(
            format: ui.ImageByteFormat.png,
          );
          if (png == null) {
            throw const FormatException('Unable to encode profile image');
          }
          return png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes);
        } finally {
          frame.image.dispose();
        }
      } finally {
        codec.dispose();
      }
    } finally {
      descriptor.dispose();
    }
  } finally {
    buffer.dispose();
  }
}
