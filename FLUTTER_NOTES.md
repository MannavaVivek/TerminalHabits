# Terminal_Habits — Flutter Implementation Notes

A desktop habit tracker with a terminal-inspired aesthetic, targeted at **macOS** and **Linux** (and trivially **Windows**) via Flutter Desktop. These notes map every visual element of the HTML mockup to recommended Flutter widgets, packages, and architecture.

---

## 1. Project shape

```
terminal_habits/
├── lib/
│   ├── main.dart
│   ├── app.dart                   // root MaterialApp, theming
│   ├── theme/
│   │   ├── theme.dart             // ThemeData + ColorScheme
│   │   ├── tokens.dart            // colors, spacing, radii
│   │   └── themes/
│   │       ├── matrix.dart        // dark green (default)
│   │       ├── amber.dart         // CRT
│   │       ├── ibm.dart           // blue
│   │       ├── solar.dart         // solarized dark
│   │       ├── nord.dart
│   │       └── mono.dart
│   ├── data/
│   │   ├── db.dart                // drift / sqlite3
│   │   ├── habit.dart             // models (freezed)
│   │   └── repository.dart
│   ├── state/
│   │   └── *.dart                 // riverpod providers
│   ├── ui/
│   │   ├── window/
│   │   │   ├── window_chrome.dart // titlebar w/ traffic lights
│   │   │   └── status_bar.dart
│   │   ├── nav/
│   │   │   └── sidebar.dart
│   │   ├── views/
│   │   │   ├── daily_view.dart
│   │   │   ├── stats_view.dart
│   │   │   ├── vacation_view.dart
│   │   │   ├── profile_view.dart
│   │   │   ├── splash_view.dart
│   │   │   └── onboarding_view.dart
│   │   ├── modals/
│   │   │   ├── new_habit_dialog.dart
│   │   │   ├── settings_dialog.dart
│   │   │   └── command_palette.dart
│   │   ├── inspector/
│   │   │   └── inspector_pane.dart
│   │   └── widgets/
│   │       ├── prompt_line.dart   // user@init.Habits$ daily
│   │       ├── tabs.dart
│   │       ├── week_strip.dart
│   │       ├── habit_row.dart
│   │       ├── habit_group.dart
│   │       ├── ascii_art.dart
│   │       ├── sparkline.dart
│   │       └── contribution_grid.dart
│   └── shortcuts/
│       └── intents.dart           // CMD+K, CMD+N, etc.
└── pubspec.yaml
```

---

## 2. Recommended packages

| Concern | Package |
|---|---|
| State management | `flutter_riverpod` (or `provider`) |
| Models / immutables | `freezed`, `json_serializable` |
| Local DB | `drift` over `sqlite3` (works everywhere on desktop) |
| Window control | `window_manager` (resizable, frameless option, set min size) |
| Native window styling on macOS | `macos_window_utils` (toolbar styles, vibrancy) |
| Tray icon | `tray_manager` |
| Global hotkeys | `hotkey_manager` |
| File picker / paths | `path_provider`, `file_picker` |
| Apple Health (mac) | `health` (iOS only — for the `[health]` tracking type, keep this stub on desktop) |
| Charts | `fl_chart` (good enough, but most charts here are custom-painted) |
| Confetti / animation | not needed — the app is intentionally quiet |

---

## 3. Theme tokens (Matrix / dark green default)

Mirror the CSS custom properties:

```dart
class TH {  // TerminalHabits tokens
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

Type: `GoogleFonts.jetBrainsMono(...)` everywhere. Sizes:

- titlebar / status bar: 11–12sp
- inspector / sidebar: 12–13sp
- body / habit rows: 14sp
- group headings: 15sp (w600)
- splash logo (ASCII): 11–12sp, line-height 1.0

---

## 4. Window chrome

On **macOS** use a frameless window and draw your own titlebar so the green/amber traffic lights and version meta look identical across platforms:

```dart
await windowManager.ensureInitialized();
const opts = WindowOptions(
  size: Size(1280, 820),
  minimumSize: Size(1080, 680),
  titleBarStyle: TitleBarStyle.hidden,
  backgroundColor: TH.bg,
);
windowManager.waitUntilReadyToShow(opts, () async {
  await windowManager.setAsFrameless();   // mac/linux
  await windowManager.show();
});
```

On Linux, `titleBarStyle: hidden` produces a clean GTK frame; on Windows you'll want `bitsdojo_window` for full custom chrome.

The "traffic lights" in the mockup are decorative — wire them via `windowManager.close()` / `minimize()` / `maximize()` so they're functional.

---

## 5. Layout — three-pane

Top-level scaffold:

```dart
Column(
  children: [
    WindowChrome(),                        // 38px tall titlebar
    Expanded(
      child: Row(
        children: [
          Sidebar(width: 200),
          const VerticalDivider(width: 1, color: TH.line),
          Expanded(child: MainPane()),     // routed view
          const VerticalDivider(width: 1, color: TH.line),
          Inspector(width: 280),
        ],
      ),
    ),
    StatusBar(),                           // 26px tall
  ],
)
```

Make the sidebar and inspector resizable with `MultiSplitView` (package `multi_split_view`) if you want tmux-style resizing — optional, but on-brand.

---

## 6. View → Widget map

| HTML view | Flutter widget | Notes |
|---|---|---|
| `SplashView` | `SplashView` | Centered Column with ASCII logo (`Text` w/ monospace), `SystemInfoBox`, prose. Tap last line ("yours to shape.") → push `OnboardingView`. |
| `OnboardingView` | `Stepper` (custom) | 4 steps; persist answers to settings table. |
| Daily | `DailyView` | `CustomScrollView` with slivers: prompt, comment, date row, week strip, habit groups. |
| Week strip | `WeekStrip` | `Row` of 7 `DayCell`s w/ horizontal scroll if narrow. Bar fill via `FractionallySizedBox` over a striped `DecoratedBox`. |
| Habit row | `HabitRow` | `InkWell` with `[ ]`/`[✓]` text, icon, label, optional meta + streak. Tap toggles, long-press → context menu (edit, archive). |
| Habit group | `HabitGroup` | `ExpansionTile` themed monospace; show `[done/total]` in trailing. |
| Stats | `StatsView` | Stack of `StatBlock`s. `OverviewBlock`, `StreaksBlock`, `RatesBlock`, `ContributionsBlock`, `DayOfWeekBlock`. |
| Contribution grid | `ContributionGrid` | `CustomPaint` over a 7×N grid of squares. 5 levels of green: `Color.lerp(bg3, green, t)`. |
| Sparkline | `Sparkline` | `CustomPaint` of vertical bars, height = value × maxHeight. |
| Day-of-week bars | `BarRow` | label / striped track with `FractionallySizedBox` / value. |
| Vacation | `VacationView` | ASCII palm tree as plain `Text`. End/extend buttons modify `vacation` row in DB. |
| New habit | `NewHabitDialog` | `Dialog` w/ custom chrome (cancel/title/save). Type radio-pills (`checkbox`/`count`/`number`/`health`). When `health` → show source tree (custom `TreeView` of categories → fields). |
| Settings | `SettingsDialog` | Two-pane dialog: left list of sections, right body. `text` section: size pills + 8 font preview cards in a 2-col grid (each renders its label in its own `TextStyle(fontFamily: name)`). |
| Command palette | `CommandPalette` | `Dialog.barrierColor: black54`, top-aligned via `Align(alignment: Alignment.topCenter, padding: 110)`. Filter list as user types. Up/Down arrows + Enter via `Shortcuts` and `Actions`. |
| Inspector | `InspectorPane` | Scrollable Column of titled blocks. Content depends on current view (`InheritedWidget` or Riverpod read). |
| Status bar | `StatusBar` | Fixed-height `Row`. Uses `Tooltip` for shortcut hints. |

---

## 7. Keyboard shortcuts

Use Flutter's `Shortcuts`/`Actions`/`Intent` system at the app root:

```dart
Shortcuts(
  shortcuts: <ShortcutActivator, Intent>{
    SingleActivator(LogicalKeyboardKey.keyK, meta: true): const PaletteIntent(),
    SingleActivator(LogicalKeyboardKey.digit1, meta: true): const GoToIntent('daily'),
    SingleActivator(LogicalKeyboardKey.digit2, meta: true): const GoToIntent('stats'),
    SingleActivator(LogicalKeyboardKey.digit3, meta: true): const GoToIntent('profile'),
    SingleActivator(LogicalKeyboardKey.keyN, meta: true): const NewHabitIntent(),
    SingleActivator(LogicalKeyboardKey.keyV, meta: true): const VacationIntent(),
    SingleActivator(LogicalKeyboardKey.comma, meta: true): const SettingsIntent(),
    SingleActivator(LogicalKeyboardKey.semicolon, shift: true): const PaletteIntent(),  // ":"
  },
  child: Actions(
    actions: { ... },
    child: Focus(autofocus: true, child: rootChild),
  ),
)
```

Within `DailyView`, bind `j/k` and arrow keys to a focused habit index, `space` to toggle. On Linux, swap `meta` for `control`. Consider `defaultTargetPlatform` to pick the right modifier per-platform.

---

## 8. Data layer (drift)

```dart
class Habits extends Table {
  IntColumn  get id        => integer().autoIncrement()();
  TextColumn get groupId   => text()();
  TextColumn get name      => text()();
  TextColumn get icon      => text().withDefault(const Constant('●'))();
  TextColumn get color     => text().withDefault(const Constant('green'))();
  TextColumn get tracking  => text()();   // checkbox|count|number|health
  IntColumn  get target    => integer().nullable()();
  TextColumn get unit      => text().nullable()();
  TextColumn get schedule  => text()();   // json: [0..6] days
  TextColumn get note      => text().nullable()();
  IntColumn  get sortIndex => integer()();
  DateTimeColumn get archivedAt => dateTime().nullable()();
}

class Completions extends Table {
  IntColumn  get id      => integer().autoIncrement()();
  IntColumn  get habitId => integer().references(Habits, #id)();
  DateTimeColumn get day => dateTime()();   // truncated to local day
  RealColumn get value   => real().withDefault(const Constant(1.0))();
}
```

Streak/shield logic lives in the repository; recompute on completion writes and cache per-habit.

---

## 9. ASCII art & monospace alignment

- Splash logo: store as a single `String` with `\n`. Render in `SelectableText` (so the user can copy-paste it — terminal-folk love that). `style: TextStyle(fontFamily: 'JetBrainsMono', fontSize: 11, height: 1.0)`.
- Vacation palm tree: same approach.
- Contribution grid is **not** ASCII — paint it.

---

## 10. Theme switching (Tweaks tab in Settings)

Each theme exports a `(ThemeData, ColorScheme)` pair. Keep current theme id in `SharedPreferences`. Don't animate the swap — flip it instantly; that fits the aesthetic.

---

## 11. Performance & feel

- Default to **120 fps** on macOS (`displayMode`) — small UI, will feel snappy.
- Disable Material ripples globally (`splashFactory: NoSplash.splashFactory`) — they're off-brand. Use a 1-frame opacity flash on tap instead.
- Cursor blink in splash: `AnimatedSwitcher` with 1 s opacity toggle.

---

## 12. What this mockup does not solve (yet)

- Real Apple Health integration on macOS (the `health` package is iOS-only). For desktop, treat `[health]` as "import a CSV / connect a future bridge."
- Sync — UI is in place; pick iCloud Drive (mac-only file sync), or build a tiny git-based sync later.
- Notifications — `flutter_local_notifications` works on macOS/Linux but is fiddly with desktop frameworks; defer to v1.0.

---

## 13. What to copy from the HTML literally

- Every `Color(0x…)` value listed in §3.
- All copy strings (the `// no nudges. no streak panic.` style is *the* product voice — keep verbatim).
- Spacing rhythm: 4 / 8 / 14 / 22 px gaps; sidebar 200, inspector 280, titlebar 38, statusbar 26.
- Border radii: 4 (controls), 6 (cards), 10 (modals), 12 (window).
- `[bracket-style]` chips — render a `Container` with `border` not a real button.
