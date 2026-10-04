import 'package:denial_clock_ui/clock_face.dart';
export 'package:denial_clock_ui/clock_face.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:denial_flutter_sdk/shell_theme.dart';
import 'package:denial_flutter_sdk/tokens.dart';
import 'package:denial_flutter_sdk/rendering.dart';
import 'package:denial_flutter_sdk/applications.dart';

part 'home_app_tile.dart';

class HomeGridItemCard extends ConsumerWidget {
  const HomeGridItemCard({
    super.key,
    required this.item,
    this.launchEnabled = true,
    required this.onLaunch,
  });

  final HomeGridItem item;
  final bool launchEnabled;
  final void Function(HomeGridItem item, Rect sourceRect) onLaunch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (item.type) {
      HomeGridItemType.clock => HomeClockWidget(
        clock: ref.watch(homeClockProvider),
      ),
      HomeGridItemType.app => _HomeAppTile(
        name: item.localApp?.titleFor(context) ?? item.app!.name,
        iconPath: item.app?.iconPath,
        icon: item.localApp?.icon,
        onTap: launchEnabled ? (rect) => onLaunch(item, rect) : null,
      ),
    };
  }
}
