# Reference desktop plugin

`ReferenceDesktop` implements the public SDK's `ShellApplication` contract and
owns the default desktop/mobile UI. This includes its layouts, decorations,
transitions, lock/keyboard/notification presentation, Settings and Welcome UI.
The package depends on the SDKs and ordinary Dart/Flutter packages, never on
`denial_dart_shell`. All platform access uses public SDK libraries.

It consumes `List<ShellSurface>`, an optional `ShellWorkArea`, an optional
`ShellLauncher`, and `List<ShellAction>` through generated constructor injection.
Surfaces own their bounds/output/visibility decisions; this plugin supplies scene
facts and mounts the SDK planes. A missing work-area provider removes native
reservations. Other root plugins can use these same SDK contracts.

The development app and generated compositions instantiate this same provider.
Standalone Settings and Welcome entry points reuse this plugin's UI with the
SDK's native service integration. There are no copies of those screens in the
shell application or SDK.

See [plugin development](../../docs/PLUGIN_DEVELOPMENT.md) for the supported API
boundary and [custom shells](../../docs/CUSTOM_SHELLS.md) for root composition.
