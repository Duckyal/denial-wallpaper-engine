import 'package:denial_flutter_sdk/materials.dart';
import 'package:flutter/material.dart';

import 'package:denial_flutter_sdk/localization.dart';

/// Page-owned commands are presented by the fixed application frame. Only the
/// active page may publish them; outgoing transition children cannot restore
/// stale callbacks. Updating these slots does not rebuild the page itself.
class SettingsChromeController extends ChangeNotifier {
  Object? _page;
  Object? _owner;
  bool _disposed = false;
  Widget? toolbar;
  Widget? footer;

  void select(Object page) {
    _page = page;
    _owner = null;
    toolbar = null;
    footer = null;
    notifyListeners();
  }

  void publish(Object page, Object owner, Widget? toolbar, Widget? footer) {
    if (_disposed || page != _page) return;
    _owner = owner;
    this.toolbar = toolbar;
    this.footer = footer;
    notifyListeners();
  }

  void remove(Object owner) {
    if (_disposed || !identical(owner, _owner)) return;
    _owner = null;
    toolbar = null;
    footer = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class SettingsChromeScope extends InheritedWidget {
  const SettingsChromeScope({
    required this.controller,
    required this.page,
    required super.child,
    super.key,
  });

  final SettingsChromeController controller;
  final Object page;

  static SettingsChromeScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SettingsChromeScope>();

  @override
  bool updateShouldNotify(SettingsChromeScope oldWidget) =>
      controller != oldWidget.controller || page != oldWidget.page;
}

class SettingsPageChrome extends StatefulWidget {
  const SettingsPageChrome({
    required this.child,
    this.toolbar,
    this.footer,
    super.key,
  });

  final Widget child;
  final Widget? toolbar;
  final Widget? footer;

  @override
  State<SettingsPageChrome> createState() => _SettingsPageChromeState();
}

class _SettingsPageChromeState extends State<SettingsPageChrome> {
  SettingsChromeController? _controller;
  int _revision = 0;

  @override
  Widget build(BuildContext context) {
    final scope = SettingsChromeScope.maybeOf(context);
    _controller = scope?.controller;
    final revision = ++_revision;
    if (scope != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || revision != _revision) return;
        scope.controller.publish(
          scope.page,
          this,
          widget.toolbar,
          widget.footer,
        );
      });
      return widget.child;
    }
    // Standalone page consumers retain access to the same actions and errors.
    return Column(
      children: [
        if (widget.toolbar != null) widget.toolbar!,
        Expanded(child: widget.child),
        if (widget.footer != null) widget.footer!,
      ],
    );
  }

  @override
  void dispose() {
    final controller = _controller;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => controller?.remove(this),
    );
    super.dispose();
  }
}

class SettingsCommandGroup extends StatelessWidget {
  const SettingsCommandGroup({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(DenialApplicationFrame.defaultInset),
    child: Align(
      alignment: AlignmentDirectional.centerEnd,
      child: DenialMaterial(
        role: DenialMaterialRole.toolbar,
        floating: true,
        inset: DenialApplicationFrame.defaultInset,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Wrap(
            alignment: WrapAlignment.end,
            spacing: 4,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: children,
          ),
        ),
      ),
    ),
  );
}

class SettingsCommand extends StatelessWidget {
  const SettingsCommand({
    required this.label,
    required this.icon,
    required this.onPressed,
    super.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: onPressed,
    icon: Icon(icon, size: 19),
    label: Text(label),
    style: TextButton.styleFrom(
      foregroundColor: context.applicationColors.foreground,
      minimumSize: const Size(44, 44),
      shape: RoundedRectangleBorder(
        borderRadius: DenialSurfaceGeometry.borderRadiusOf(context, inset: 6),
      ),
    ),
  );
}

/// Error details open only on request. Dismissal lasts until the error changes
/// or clears, and does not alter the underlying settings operation.
class SettingsErrorNotice extends StatefulWidget {
  const SettingsErrorNotice({
    required this.message,
    this.onRetry,
    this.onDismiss,
    super.key,
  });

  final String? message;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;

  @override
  State<SettingsErrorNotice> createState() => _SettingsErrorNoticeState();
}

class _SettingsErrorNoticeState extends State<SettingsErrorNotice> {
  bool _dismissed = false;

  @override
  void didUpdateWidget(SettingsErrorNotice oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.message != oldWidget.message) _dismissed = false;
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    if (message == null || message.isEmpty || _dismissed) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: DenialMaterial(
        role: DenialMaterialRole.toolbar,
        floating: true,
        inset: 16,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                liveRegion: true,
                child: Text(
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (widget.onRetry != null)
                    TextButton(
                      onPressed: widget.onRetry,
                      child: Text(l10n.commonRetry),
                    ),
                  IconButton(
                    tooltip: l10n.quickSettingsOpenDetails(l10n.commonError),
                    icon: const Icon(Icons.info_outline_rounded),
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(l10n.commonError),
                        content: SingleChildScrollView(
                          child: SelectableText(message),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(l10n.actionDismiss),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.actionDismiss,
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () {
                      setState(() => _dismissed = true);
                      widget.onDismiss?.call();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
