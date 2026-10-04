import 'dart:math' as math;

double _luminance(int color) {
  double linear(int shift) {
    final value = ((color >> shift) & 255) / 255;
    return value <= .04045
        ? value / 12.92
        : math.pow((value + .055) / 1.055, 2.4).toDouble();
  }

  return .2126 * linear(16) + .7152 * linear(8) + .0722 * linear(0);
}

double welcomeContrastRatio(int first, int second) {
  final a = _luminance(first);
  final b = _luminance(second);
  return (math.max(a, b) + .05) / (math.min(a, b) + .05);
}

int welcomeOnAccent(int background) =>
    welcomeContrastRatio(background, 0xff000000) >=
        welcomeContrastRatio(background, 0xffffffff)
    ? 0xff000000
    : 0xffffffff;

/// Keep the requested hue when readable; otherwise move toward a neutral
/// endpoint until it is readable on every opaque application surface.
int welcomeReadableAccent(int accent, List<int> surfaces) {
  double score(int color) => surfaces
      .map((surface) => welcomeContrastRatio(color, surface))
      .reduce(math.min);
  final source = accent | 0xff000000;
  if (score(source) >= 4.5) return source;
  final endpoint = score(0xff000000) > score(0xffffffff) ? 0 : 255;
  for (var step = 1; step <= 255; step++) {
    int channel(int shift) =>
        (((source >> shift) & 255) * (255 - step) / 255 + endpoint * step / 255)
            .round();
    final candidate =
        0xff000000 | channel(16) << 16 | channel(8) << 8 | channel(0);
    if (score(candidate) >= 4.5) return candidate;
  }
  return endpoint == 0 ? 0xff000000 : 0xffffffff;
}
