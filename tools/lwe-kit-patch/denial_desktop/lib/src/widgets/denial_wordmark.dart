import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:denial_flutter_sdk/shell_theme.dart';
import 'package:denial_flutter_sdk/tokens.dart';

const denialWordmarkAsset =
    'packages/denial_flutter_sdk/assets/branding/denial-dark.svg';
const denialWordmarkAspectRatio = 49 / 15;

class DenialWordmark extends StatelessWidget {
  const DenialWordmark({
    required this.semanticsLabel,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    super.key,
  });

  final String semanticsLabel;
  final BoxFit fit;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      denialWordmarkAsset,
      colorMapper: _DenialWordmarkColorMapper(context.shellColors.textPrimary),
      fit: fit,
      alignment: alignment,
      allowDrawingOutsideViewBox: true,
      clipBehavior: Clip.none,
      semanticsLabel: semanticsLabel,
    );
  }
}

@immutable
class _DenialWordmarkColorMapper extends ColorMapper {
  const _DenialWordmarkColorMapper(this.foreground);

  final Color foreground;

  @override
  Color substitute(
    String? id,
    String elementName,
    String attributeName,
    Color color,
  ) => color == ShellBrandColors.wordmarkAssetForeground ? foreground : color;

  @override
  bool operator ==(Object other) =>
      other is _DenialWordmarkColorMapper && other.foreground == foreground;

  @override
  int get hashCode => foreground.hashCode;
}
