import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:denial_flutter_sdk/models.dart';
import 'package:denial_flutter_sdk/system_services.dart';
import 'package:denial_flutter_sdk/settings.dart';

export 'package:denial_flutter_sdk/state.dart';

final clipboardTrayProvider =
    NotifierProvider<ClipboardTrayController, ClipboardTrayState>(
      ClipboardTrayController.new,
    );

@immutable
class ClipboardTrayState {
  const ClipboardTrayState({
    this.open = false,
    this.progress = 0,
    this.gestureActive = false,
    this.monitorId,
  });

  final bool open;
  final double progress;
  final bool gestureActive;
  final int? monitorId;

  bool get painted => progress > 0.001;

  ClipboardTrayState copyWith({
    bool? open,
    double? progress,
    bool? gestureActive,
    int? monitorId,
  }) {
    return ClipboardTrayState(
      open: open ?? this.open,
      progress: progress ?? this.progress,
      gestureActive: gestureActive ?? this.gestureActive,
      monitorId: monitorId ?? this.monitorId,
    );
  }
}

class ClipboardTrayController extends Notifier<ClipboardTrayState> {
  @override
  ClipboardTrayState build() => const ClipboardTrayState();

  void open({int? monitorId}) {
    if (!state.open || (monitorId != null && monitorId != state.monitorId)) {
      state = state.copyWith(open: true, monitorId: monitorId);
    }
  }

  void close() {
    if (state.open || state.gestureActive) {
      state = state.copyWith(open: false, gestureActive: false);
    }
  }

  void toggle({int? monitorId}) =>
      state.open ? close() : open(monitorId: monitorId);

  void setMotionProgress(double value, {bool? gestureActive}) {
    final progress = value.clamp(0.0, 1.0).toDouble();
    final nextGestureActive = gestureActive ?? state.gestureActive;
    if ((state.progress - progress).abs() < 0.0001 &&
        state.gestureActive == nextGestureActive) {
      return;
    }
    state = state.copyWith(
      progress: progress,
      gestureActive: nextGestureActive,
    );
  }

  void settle({required bool open}) {
    state = state.copyWith(open: open, gestureActive: false);
  }
}

Offset clipboardTrayWindowOffset(
  ClipboardTrayState tray,
  ShellLayoutSettings layout, {
  int? monitorId,
  DisplayLayout? displayLayout,
  Size? outputSize,
}) {
  if (monitorId != null &&
      tray.monitorId != null &&
      monitorId != tray.monitorId) {
    return Offset.zero;
  }
  final targetOutput = clipboardTrayTargetOutput(tray, displayLayout);
  final effectiveSize = outputSize ?? targetOutput?.logicalRect.size;
  final extent = effectiveSize == null
      ? layout.clipboardTrayExtent
      : clipboardTrayExtentForSize(layout, effectiveSize);
  final travel = extent * tray.progress;
  return switch (layout.clipboardTrayEdge) {
    ClipboardTrayEdge.left => Offset(travel, 0),
    ClipboardTrayEdge.right => Offset(-travel, 0),
    ClipboardTrayEdge.top => Offset(0, travel),
    ClipboardTrayEdge.bottom => Offset(0, -travel),
  };
}

DisplayOutput? clipboardTrayTargetOutput(
  ClipboardTrayState tray,
  DisplayLayout? layout,
) {
  if (layout == null || layout.outputs.isEmpty) {
    return null;
  }
  if (tray.monitorId case final monitorId?) {
    for (final output in layout.outputs) {
      if (output.monitorId == monitorId) {
        return output;
      }
    }
  }
  return layout.mainOutput ?? layout.outputs.first;
}

double clipboardTrayExtentForSize(ShellLayoutSettings layout, Size outputSize) {
  final vertical =
      layout.clipboardTrayEdge == ClipboardTrayEdge.left ||
      layout.clipboardTrayEdge == ClipboardTrayEdge.right;
  final available = vertical ? outputSize.width : outputSize.height;
  final limit = math.max(
    clipboardTrayMinimumExtent,
    math.min(clipboardTrayMaximumExtent, available - 96.0),
  );
  return layout.clipboardTrayExtent
      .clamp(clipboardTrayMinimumExtent, limit)
      .toDouble();
}

@immutable
class ClipboardDataKey {
  const ClipboardDataKey(this.itemId, this.mimeType);

  final int itemId;
  final String mimeType;

  @override
  bool operator ==(Object other) {
    return other is ClipboardDataKey &&
        other.itemId == itemId &&
        other.mimeType == mimeType;
  }

  @override
  int get hashCode => Object.hash(itemId, mimeType);
}

final clipboardEntryDataProvider = FutureProvider.autoDispose
    .family<ClipboardHistoryData, ClipboardDataKey>((ref, key) {
      return ref
          .watch(clipboardHistoryServiceProvider)
          .readData(key.itemId, key.mimeType);
    });

const int _maxLocalClipboardPreviewBytes = 16 * 1024 * 1024;

final clipboardLocalFilePreviewProvider = FutureProvider.autoDispose
    .family<Uint8List?, Uri>((ref, uri) async {
      if (!clipboardUriCanRenderAsImage(uri)) {
        return null;
      }
      final file = File.fromUri(uri);
      final stat = await file.stat();
      if (stat.type != FileSystemEntityType.file ||
          stat.size <= 0 ||
          stat.size > _maxLocalClipboardPreviewBytes) {
        return null;
      }
      final handle = await file.open();
      try {
        final bytes = await handle.read(_maxLocalClipboardPreviewBytes + 1);
        return bytes.length <= _maxLocalClipboardPreviewBytes ? bytes : null;
      } finally {
        await handle.close();
      }
    });

String? clipboardImageMimeType(ClipboardHistoryEntry entry) {
  const preferred = <String>[
    'image/png',
    'image/webp',
    'image/jpeg',
    'image/jpg',
  ];
  for (final mimeType in preferred) {
    for (final offered in entry.mimeTypes) {
      if (offered.toLowerCase() == mimeType) {
        return offered;
      }
    }
  }
  return null;
}

List<Uri> clipboardFileUris(String value) {
  final result = <Uri>[];
  for (final line in value.split(RegExp(r'\r?\n'))) {
    final candidate = line.trim();
    if (candidate.isEmpty || candidate.startsWith('#')) {
      continue;
    }
    final uri = Uri.tryParse(candidate);
    if (uri != null && (uri.scheme == 'file' || uri.scheme.isEmpty)) {
      result.add(uri.scheme.isEmpty ? Uri.file(candidate) : uri);
    }
  }
  return List<Uri>.unmodifiable(result);
}

bool clipboardUriCanRenderAsImage(Uri uri) {
  if (uri.scheme != 'file') {
    return false;
  }
  final path = uri.path.toLowerCase();
  return path.endsWith('.jpg') ||
      path.endsWith('.jpeg') ||
      path.endsWith('.png') ||
      path.endsWith('.webp') ||
      path.endsWith('.gif') ||
      path.endsWith('.bmp');
}

String? clipboardFileMimeType(ClipboardHistoryEntry entry) {
  for (final mimeType in entry.mimeTypes) {
    if (mimeType.toLowerCase() == 'text/uri-list') {
      return mimeType;
    }
  }
  return null;
}
