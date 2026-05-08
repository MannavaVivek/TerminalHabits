# Build & Packaging Spec

> Per-platform build commands, packaging artifacts, native config, and signing notes. Treat the commands as canonical — agents should run them verbatim.

---

## 1. Local dev setup

### One-time

```bash
# Flutter SDK
flutter doctor
flutter --version       # confirm >= 3.24.0

# Enable desktop targets
flutter config --enable-macos-desktop
flutter config --enable-linux-desktop
```

### Per-clone

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # freezed + drift codegen
```

Re-run codegen any time a `freezed` or drift class changes.

### Daily loop

```bash
# macOS dev
flutter run -d macos

# Linux dev (Phase 9+)
flutter run -d linux

# Android dev (Phase 10+)
flutter run -d android   # device must be connected with USB debugging
```

---

## 2. macOS (Phase 1+)

### Build

```bash
flutter build macos --release
# → build/macos/Build/Products/Release/TerminalHabits.app
```

### Native config

| File | Setting |
|---|---|
| `macos/Runner/Info.plist` | `LSApplicationCategoryType = public.app-category.productivity`. `CFBundleName = TerminalHabits`. |
| `macos/Runner/DebugProfile.entitlements` | `com.apple.security.app-sandbox = true`, `com.apple.security.network.client = true` (Phase 11 sync only — leave off until then). |
| `macos/Runner/Release.entitlements` | Same as Debug, plus `com.apple.security.files.user-selected.read-write = true` for export/import. |
| `macos/Runner/Base.lproj/MainMenu.xib` | Default Flutter — no edits. |
| `macos/Podfile` | Set `platform :osx, '10.14'`. |

### Window setup

Implemented in code, not config — see [tech_stack.md](tech_stack.md) §package matrix and the snippet in `FLUTTER_NOTES.md` §4. Must run inside `windowManager.ensureInitialized()` before `runApp`.

### DMG packaging

```bash
npm install -g appdmg                # one-time
appdmg appdmg.json dist/TerminalHabits.dmg
```

`appdmg.json` lives at repo root; create in Phase 1.

```json
{
  "title": "TerminalHabits",
  "icon": "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png",
  "background": "assets/dmg_background.png",
  "contents": [
    { "x": 410, "y": 220, "type": "link", "path": "/Applications" },
    { "x": 130, "y": 220, "type": "file", "path": "build/macos/Build/Products/Release/TerminalHabits.app" }
  ]
}
```

### Code signing & notarization (deferred until distribution)

Until you start sharing builds outside your machine, skip this. When you start distributing:

```bash
codesign --deep --force --options runtime \
  --sign "Developer ID Application: <NAME> (<TEAMID>)" \
  build/macos/Build/Products/Release/TerminalHabits.app

xcrun notarytool submit dist/TerminalHabits.dmg \
  --keychain-profile "AC_PASSWORD" --wait

xcrun stapler staple dist/TerminalHabits.dmg
```

Until then, dogfooding builds will show the "unidentified developer" Gatekeeper prompt — that's fine.

---

## 3. Linux (Phase 9+)

### System dependencies

```bash
# Ubuntu 22.04 / Debian 12
sudo apt-get install -y \
  clang cmake ninja-build pkg-config \
  libgtk-3-dev liblzma-dev libstdc++-12-dev \
  libsqlite3-dev
```

### Build

```bash
flutter build linux --release
# → build/linux/x64/release/bundle/terminal_habits   (binary + lib/data)
```

### Packaging

```bash
dart pub global activate flutter_distributor    # one-time
flutter_distributor package --platform linux --targets deb,zip
# → dist/terminal-habits-<version>-linux.deb
# → dist/terminal-habits-<version>-linux.zip
```

`distribute_options.yaml` lives at repo root. Phase 9 adds it.

### Tray icon

Place `assets/tray_icon.png` (32×32, monochrome). `tray_manager` reads it via `assets:` declaration in `pubspec.yaml`.

### Wayland vs X11

Frameless windows (`titleBarStyle: hidden`) work under both, but test both manually before declaring Phase 9 done. On older systems, force X11 with:

```bash
GDK_BACKEND=x11 ./terminal_habits
```

---

## 4. Android (Phase 10+)

### Native config

| File | Setting |
|---|---|
| `android/app/build.gradle` | `minSdkVersion 21`, `targetSdkVersion 34`, `compileSdkVersion 34`. |
| `android/app/src/main/AndroidManifest.xml` | `android:label = "TerminalHabits"`. Permissions: `android.permission.health.READ_STEPS`, `android.permission.health.READ_SLEEP` (only when health habit exists). |
| `android/app/src/main/res/values/styles.xml` | `windowBackground = @color/th_bg` (matches `TH.bg = #0B1014`). |
| `android/app/src/main/res/drawable/launch_background.xml` | Solid `TH.bg` — no Material splash. |

### Build

```bash
# Architecture-split APKs (smaller per-arch downloads)
flutter build apk --release --split-per-abi
# → build/app/outputs/flutter-apk/app-arm64-v8a-release.apk (and others)

# Universal APK (one big one, easier sideloading)
flutter build apk --release
# → build/app/outputs/flutter-apk/app-release.apk
```

For Play Store distribution (deferred):

```bash
flutter build appbundle --release
# → build/app/outputs/bundle/release/app-release.aab
```

### Signing (Phase 10 dogfooding)

For dogfooding, debug-signed APKs are fine (`flutter build apk --debug`). For release signing, generate a keystore once:

```bash
keytool -genkey -v -keystore ~/.android/terminal-habits-upload.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Wire via `android/key.properties` (gitignored) and `android/app/build.gradle` `signingConfigs`.

### Health Connect

Add to `AndroidManifest.xml` only when `[health]` habits exist (or unconditionally — Health Connect is opt-in at the OS level):

```xml
<uses-permission android:name="android.permission.health.READ_STEPS"/>
<uses-permission android:name="android.permission.health.READ_SLEEP"/>

<queries>
  <package android:name="com.google.android.apps.healthdata"/>
</queries>
```

---

## 5. CI/CD

**Out of scope for v1.** All builds are local. When CI is added (post-1.0):

- Use GitHub Actions or similar.
- `macos-latest` runner for macOS + iOS (if ever).
- `ubuntu-latest` for Linux + Android.
- Cache `pub-cache` and `~/.gradle` aggressively.
- Run `flutter analyze && flutter test` on every PR.
- Build artifacts on tag pushes only.

---

## 6. Versioning

`pubspec.yaml`:

```yaml
version: 0.1.0+1     # semver+build_number
```

- Phase 0 → `0.1.0`
- Phase 1 → `0.2.0`
- Phase 2 → `0.2.1`
- Phase 3 → `0.2.2`
- Phase 4 → `0.2.3`
- Phase 5 → `0.2.4`
- Phase 6 → `0.2.5`
- Phase 7 → `0.3.0`
- Phase 8 → `0.3.1`
- Phase 9 → `0.4.0`
- Phase 10 → `0.5.0` (first cross-platform build)
- Phase 11 → `1.0.0` (first sync-capable build)

Build number increments on every release artifact, even pre-release. macOS reads it as `CFBundleVersion`; Android reads it as `versionCode`.

---

## 7. Reproducibility checklist

Before tagging any release:

1. `flutter clean`
2. Delete `~/.pub-cache/hosted/pub.dev/<modified-package>/` if you've been live-editing a dep.
3. `flutter pub get`
4. `dart run build_runner build --delete-conflicting-outputs`
5. `flutter analyze --no-fatal-infos`
6. `flutter test`
7. Build for each target platform that this release supports.
8. Manually exercise the phase-exit smoke script.
9. Tag: `git tag v0.X.0 && git push --tags`.
