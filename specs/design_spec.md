# Design Spec — TerminalHabits

> Visual language: tokens, layout grids, themes, animation policy. Visual-implementation reference is [`../FLUTTER_NOTES.md`](../FLUTTER_NOTES.md). This doc *governs*; FLUTTER_NOTES *illustrates*.

---

## 1. Design tokens

### Colors (Matrix theme — default)

```dart
class TH {
  static const bg      = Color(0xFF0B1014);
  static const bg1     = Color(0xFF0E1419);
  static const bg2     = Color(0xFF131B22);
  static const bg3     = Color(0xFF1A232C);
  static const line    = Color(0xFF1D2832);
  static const line2   = Color(0xFF243140);

  static const fg      = Color(0xFFCDD6E0);
  static const fgDim   = Color(0xFF8A96A3);
  static const fgMute  = Color(0xFF5A6776);
  static const fgFaint = Color(0xFF3A4654);

  static const green   = Color(0xFF5CE39A);
  static const amber   = Color(0xFFF5B048);
  static const blue    = Color(0xFF6CB6FF);
  static const purple  = Color(0xFFC084FC);
  static const teal    = Color(0xFF5EEAD4);
  static const red     = Color(0xFFEF6B6B);
}
```

Other themes override these via a `ColorScheme`-like sealed class — see §5. **Never reference raw `Color(0x…)` values outside the theme module.**

### Typography

- Default family: **JetBrains Mono** (via `google_fonts`).
- All UI is monospace. Settings → font family lets users swap to: IBM Plex Mono, Fira Code, JetBrains Mono, Iosevka, Source Code Pro, Cascadia Code, Hack, Anonymous Pro.
- Sizes:
  | Use | Size | Weight |
  |---|---|---|
  | Splash logo | 11sp | 400 |
  | Titlebar / status bar | 11–12sp | 400 |
  | Inspector / sidebar | 12–13sp | 400 |
  | Body / habit row | 14sp | 400 |
  | Group heading | 15sp | 600 |
  | Section heading (stats) | 13sp | 600, uppercase |
- Line height: 1.2 for body. 1.0 for ASCII art (so it stays gridded).
- Letter spacing: 0 everywhere (monospace).

### Spacing scale

`4 / 8 / 14 / 22 / 36`. Arbitrary px values are forbidden. Use the scale.

### Border radii

| Use | Radius |
|---|---|
| Buttons, chips, controls | 4 |
| Cards (bordered boxes) | 6 |
| Modals | 10 |
| Window | 12 (desktop only — frameless windows draw their own corner) |

### Border widths

Always 1px. Bordered boxes use `Border.all(width: 1, color: TH.line)`. Active/focused state uses `TH.line2` instead. There is no 2px or 0.5px option.

### Iconography

- Habit icons are single Unicode characters (typed by the user). Default `●`. We do not ship an icon font.
- Tab and command icons are ASCII-bracketed labels (`[ daily ]`, `[ + ]`), not glyphs.

---

## 2. Three-pane layout (desktop, ≥720px)

```
┌──────────────────────────────────────────────────────────────────┐
│ ⬤ ⬤ ⬤  TerminalHabits                                  v0.x · matrix │  ← WindowChrome (38px)
├───────────┬───────────────────────────────────┬──────────────────┤
│           │                                   │                  │
│           │                                   │                  │
│  Sidebar  │              MainPane             │     Inspector    │
│   200px   │       (route-driven, fluid)       │       280px      │
│           │                                   │                  │
│           │                                   │                  │
├───────────┴───────────────────────────────────┴──────────────────┤
│ daily · 5/12 done · matrix theme · cmd+k for palette             │  ← StatusBar (26px)
└──────────────────────────────────────────────────────────────────┘
```

### WindowChrome (38px)

- Three traffic lights (red close, amber minimize, green maximize), wired via `windowManager`.
- Title (`TerminalHabits`) centered.
- Right-side meta: `v0.x` and current theme id.
- Drag region for window movement (Flutter's `DragToMoveArea`).

### Sidebar (200px)

- Top: `${user}@TerminalHabits` prompt header.
- Vertical list of nav items: `[ daily ]`, `[ stats ]`, `[ profile ]`.
- Below: `groups:` header + collapsible group list with `[done/total]` chips.
- Bottom: `[ + new ]` (full-width bordered button).

### MainPane (fluid)

- Horizontal padding: 22px.
- Vertical padding: 14px top, 22px bottom.
- Content scrolls; pane chrome doesn't.

### Inspector (280px)

- Shares the right edge with the window border.
- Vertical-stack of titled sub-blocks. Each block: 14px outer padding, 1px border in `TH.line`.
- Scrollable independently of MainPane.

### StatusBar (26px)

- Single row, 11sp, fg=`TH.fgDim`.
- Left: current view + counts.
- Right: `cmd+k for palette` hint, theme id.

### Resizable splits (optional, Phase 7 polish)

- `multi_split_view` package; user can drag the dividers between Sidebar/Main and Main/Inspector.
- Min sidebar: 160px. Min inspector: 220px.
- Persist sizes to `Settings` keys `layout.sidebarWidth`, `layout.inspectorWidth`.

---

## 3. Single-pane layout (mobile / desktop <720px)

When `LayoutBuilder.maxWidth < 720`, collapse to:

```
┌──────────────────────────────┐
│           MainPane           │
│                              │
│                              │
│                              │
│                              │
│                              │
│                              │
│                              │
│                       ┌────┐ │
│                       │ +  │ │  ← FAB-style command bridge trigger
│                       └────┘ │
├──────────────────────────────┤
│  [ daily ] [ stats ] [ prof ]│  ← Bottom tab bar (64px)
└──────────────────────────────┘
```

Notes:
- WindowChrome is hidden (system status bar is themed instead — see §6.2).
- StatusBar is hidden (its information moves into MainPane headers and Inspector drawer).
- Sidebar collapses entirely; nav is the bottom tab bar.
- Inspector collapses to a bottom-sheet drawer (see [input_spec.md](input_spec.md) §3.4).

The breakpoint is global: **a small desktop window also gets the mobile layout.** This gives us "free" responsiveness during desktop development.

---

## 4. Component patterns

### Bordered box (the only container pattern)

```dart
DecoratedBox(
  decoration: BoxDecoration(
    color: TH.bg1,
    border: Border.all(color: TH.line, width: 1),
    borderRadius: BorderRadius.circular(6),
  ),
  child: Padding(padding: EdgeInsets.all(14), child: child),
)
```

Hover/focus state on desktop adds: `border: Border.all(color: TH.line2)`. No shadow, no elevation, no inner glow.

### Bracket-style chip

```
[ done ]   [ daily ]   [ + new ]
```

Implemented as bordered text — never a Material chip:

```dart
DecoratedBox(
  decoration: BoxDecoration(
    border: Border.all(color: TH.line, width: 1),
    borderRadius: BorderRadius.circular(4),
  ),
  child: Padding(
    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    child: Text(label, style: monoStyle),
  ),
)
```

The `[ ` and ` ]` are *part of the label string*, not faked with side borders.

### Prompt line

```
${user}@TerminalHabits$ daily
```

- `${user}` is `TH.green`.
- `@TerminalHabits` is `TH.fgDim`.
- `$` is `TH.fgMute`.
- ` daily` (the cwd-equivalent) is `TH.fg`.

This pattern is used at the top of DailyView and as decoration in onboarding/splash.

### Habit row

See [feature_spec.md](feature_spec.md) §3.2. Visual: monospace alignment is critical. The checkbox `[ ]` / `[✓]` / `[~]` / `[!]` is always 3 characters wide so columns align across rows.

---

## 5. Themes

Six built-in themes. Each is a single Dart file under `lib/theme/themes/` exporting a `(ThemeData, ColorScheme)` tuple keyed by an enum `ThemeId`.

| Id | Hue | Bg | Notes |
|---|---|---|---|
| `matrix` | green `#5CE39A` | dark teal-black `#0B1014` | Default. The Matrix-y look. |
| `amber` | warm amber `#F5B048` | warm black `#0F0B07` | CRT amber phosphor. |
| `ibm` | bright blue `#6CB6FF` | cool black `#080B14` | IBM 3270 vibe. |
| `solar` | base from Solarized Dark palette | `#002B36` | Solarized. |
| `nord` | Nord palette accents | `#2E3440` | Nord. |
| `mono` | white `#E0E0E0` accent | pure black `#000000` | High-contrast. Recommended for a11y. |

Theme switch is **instant** (no animation). User selects a theme card in Settings → Tweaks; the entire UI re-renders next frame.

The accent color of the active theme is what we mean when widgets reference `TH.green` — it's the *theme accent*, not literally green. Define a `ThemeData.extension` for the accent and read it via `Theme.of(context).extension<TH>()!.accent`.

(That said, the constants in §1 stay literally named `green/amber/etc.` for the canonical Matrix theme. Renaming them muddles the design reference.)

---

## 6. Platform-specific layout adjustments

### 6.1 Window chrome (desktop)

- macOS: `windowManager.setAsFrameless()`. Traffic lights in our chrome, real ones hidden.
- Linux: same. On Wayland with mutter, frameless works; on i3/sway, it works but maximize might behave oddly — known limitation, document at Phase 9 exit.
- Windows: out of scope for v1 (D-002 makes it Phase 11+).

### 6.2 Android system bars

- Status bar: `SystemUiOverlayStyle(statusBarColor: TH.bg, statusBarIconBrightness: Brightness.light)`.
- Navigation bar (gesture/3-button): `systemNavigationBarColor: TH.bg1`.
- No edge-to-edge in v1 (avoids cutout/insets complexity); content keeps below the system status bar.

### 6.3 Cursor (desktop)

- Pointing: `SystemMouseCursors.basic` for non-interactive, `SystemMouseCursors.click` for tappable widgets, `SystemMouseCursors.text` for inputs.
- We do not customize the cursor sprite.

---

## 7. Animation policy

The app is intentionally quiet. The full list of animations:

| Animation | Where | Duration |
|---|---|---|
| Cursor blink | Splash | 1000 ms opacity toggle |
| Tap-flash | Habit row, bordered buttons | 1 frame opacity to 0.4, then back |
| Sheet slide-in (mobile inspector / context menu) | Mobile | 180 ms cubic, no overshoot |
| Bottom-sheet drag | Mobile inspector | physics-driven, follows finger |
| Modal fade | Command palette, dialogs | 120 ms fade only, no scale or slide |

### Forbidden animations

- Material ink ripples (set `splashFactory: NoSplash.splashFactory` globally).
- Hero transitions.
- `AnimatedContainer` for color/border state changes (instant flip is the look).
- Confetti, lottie, particles, anything illustrative.
- Page transitions on `Navigator` push: use `kNoTransitionsBuilder` for desktop, mobile gets the modal fade above.

```dart
ThemeData(
  pageTransitionsTheme: const PageTransitionsTheme(builders: {
    TargetPlatform.macOS:   kNoTransitionsBuilder,
    TargetPlatform.linux:   kNoTransitionsBuilder,
    TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),  // 120ms fade
  }),
  splashFactory: NoSplash.splashFactory,
);
```

(`kNoTransitionsBuilder` is `NoTransitionsBuilder` from `package:flutter/material.dart`.)

---

## 8. Performance targets

- Cold start to splash: ≤ 1.5 s on a 2020 MacBook Pro / Pixel 5.
- DailyView first paint after splash: ≤ 200 ms with up to 50 habits.
- Habit toggle round-trip (tap → DB write → row repaint): ≤ 80 ms perceived.
- 60 fps minimum, 120 fps target on macOS via `displayMode` API.
- Memory: ≤ 150 MB resident on macOS, ≤ 80 MB on Android.

Profile with Flutter DevTools at every phase exit; record numbers in `specs/_phase_logs/phase_N.md`.

---

## 9. Iconography & assets

- App icon: monogram `i.H` in theme accent, on `TH.bg`. Generated at 16/32/64/128/256/512/1024 sizes.
  - macOS: `.icns` via `iconutil`.
  - Linux: `.png` family in `linux/runner/resources/`.
  - Android: adaptive icon — foreground `i.H` glyph, background flat `TH.bg`.
- Splash ASCII: `assets/ascii/logo.txt`. Plain text, line endings `\n`, max 60 chars wide.
- Vacation ASCII: `assets/ascii/palm.txt`.
- DMG background: `assets/dmg_background.png` (640×320).

All assets declared in `pubspec.yaml` under `flutter.assets`.

---

## 10. Visual regression testing

Two golden tests gate each phase:

- `splash_view_golden_test.dart`: SplashView at 1280×820, Matrix theme.
- `daily_view_populated_golden_test.dart`: DailyView with the test fixture's 7 habits in 2 groups, 3 completed today, Matrix theme.

Re-bless goldens deliberately (never blanket `--update-goldens`). Failures are surfaced in PR review and require a written justification.
