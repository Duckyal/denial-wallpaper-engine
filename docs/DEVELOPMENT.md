# Developing the Wallpaper Engine plugin

Each `plugins/PACKAGE_NAME/` directory is an independently selectable Dart
package. Run Pub and analysis from that package directory. The repository root
is not a Pub workspace or a plugin.

## 1. Prepare Denial's matching tools

```sh
denial-plugins prepare
DENIAL_PLUGIN_STATE="${XDG_STATE_HOME:-$HOME/.local/state}/denial/plugins"
DENIAL_PLUGIN_FLUTTER="$(jq -er '.flutter' "$DENIAL_PLUGIN_STATE/configuration.json")"
DENIAL_PLUGIN_RUNTIME="$(jq -er '.runtime' "$DENIAL_PLUGIN_STATE/configuration.json")"
DENIAL_PLUGIN_FLUTTER_ROOT="$(dirname "$(dirname "$DENIAL_PLUGIN_FLUTTER")")"
DENIAL_PLUGIN_DART="$DENIAL_PLUGIN_FLUTTER_ROOT/bin/cache/dart-sdk/bin/dart"
```

## 2. Open the package

```sh
cd plugins/denial_wallpaper_engine
```

## 3. Write local SDK overrides manually

Create `pubspec_overrides.yaml`:

```yaml
dependency_overrides:
  denial_sdk:
    path: /ABSOLUTE/RUNTIME/packages/denial_sdk
  denial_flutter_sdk:
    path: /ABSOLUTE/RUNTIME/packages/denial_flutter_sdk
```

## 4. Select the editor SDK manually

Create `.vscode/settings.json`:

```json
{
  "dart.flutterSdkPath": "/ABSOLUTE/FLUTTER",
  "dart.sdkPath": "/ABSOLUTE/FLUTTER/bin/cache/dart-sdk"
}
```

## 5. Resolve and check

```sh
"$DENIAL_PLUGIN_FLUTTER" pub get
"$DENIAL_PLUGIN_DART" format --output=none --set-exit-if-changed lib
"$DENIAL_PLUGIN_DART" analyze --fatal-infos lib
```

## 6. Build and install

```sh
denial-plugins --local add "$PWD"
denial-plugins plan
denial-plugins build CANDIDATE_ID
denial-plugins activate CANDIDATE_ID
```
