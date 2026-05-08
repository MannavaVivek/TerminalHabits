# Tech Stack — TerminalHabits

> Authoritative list of frameworks, languages, and packages. Adding a dependency that isn't listed here requires a Decision Log entry in [constitution.md](constitution.md).

---

## 1. Toolchain

| Component | Version target | Notes |
|---|---|---|
| Flutter SDK | `>= 3.24.0` (stable channel) | Pin in `pubspec.yaml` via `environment.flutter`. |
| Dart | `>= 3.5.0` | Sealed classes + pattern matching are required for the command parser. |
| Xcode | `>= 15.4` | macOS builds. |
| Android SDK | compileSdk 34, minSdk 21, targetSdk 34 | See [build_spec.md](build_spec.md). |
| Linux toolchain | clang, ninja, GTK 3 dev headers, `libsqlite3-dev` | Phase 9. |

CI/CD is out of scope for v1 — local builds only. See `build_spec.md` §5.

---

## 2. Architectural layers

```
┌────────────────────────────────────────────────┐
│  ui/        widgets, views, modals             │  ← only this layer reads dart:io
├────────────────────────────────────────────────┤
│  state/     riverpod providers (notifiers)     │
├────────────────────────────────────────────────┤
│  domain/    pure-Dart logic: streaks, schedule, │
│             command parser (sealed classes)    │
├────────────────────────────────────────────────┤
│  data/      drift database, repositories       │
└────────────────────────────────────────────────┘
```

Rules:
- **No layer reaches up.** `data/` cannot import `state/`. `domain/` cannot import `ui/`. State imports domain + data.
- **Only `ui/` is allowed to use `Platform.isAndroid` or `LayoutBuilder` to branch on platform.** Lower layers are platform-agnostic.
- **Models are immutable.** Use `freezed` for every domain/data type. Never expose mutable lists or maps from a provider.

---

## 3. Package matrix

### Core (required, all phases)

| Package | Purpose | Pinned to |
|---|---|---|
| `flutter_riverpod` | State management | latest stable 2.x |
| `freezed` + `freezed_annotation` | Immutable data classes | latest 2.x |
| `json_serializable` | JSON ser/de for export/import | latest 6.x |
| `drift` + `drift_dev` | Local SQL DB with codegen | latest 2.x |
| `sqlite3_flutter_libs` | Bundled SQLite for mobile | latest |
| `path_provider` | Cross-platform app data dir | latest |
| `google_fonts` | JetBrains Mono + theme fonts | latest |
| `intl` | Date formatting, locale-aware day boundaries | latest |
| `shared_preferences` | Theme id, font size, last-opened view | latest |

### Desktop only (Phase 1–6)

| Package | Purpose |
|---|---|
| `window_manager` | Frameless window, min size, transparency |
| `macos_window_utils` | macOS-specific toolbar styles, vibrancy (Phase 1) |
| `tray_manager` | System tray icon (Phase 9, Linux) |
| `hotkey_manager` | Global show/hide hotkey (Phase 9+, optional) |
| `multi_split_view` | Resizable sidebar/inspector (optional, Phase 7 polish) |

### Mobile only (Phase 10)

| Package | Purpose |
|---|---|
| `health` (Android variant via `health_connect`) | Step/sleep import for `[health]` habits |
| `flutter_haptic` *or* `HapticFeedback` from `services` | Tactile click on button presses |

### Charts & paint

| Package | Purpose |
|---|---|
| `fl_chart` | Reserved for future use only |

Most charts (sparkline, contribution grid, day-of-week bars) are **custom-painted** with `CustomPaint`. `fl_chart` is allowed only if a chart is too complex to hand-paint in under ~80 lines.

### Forbidden / discouraged

| Package | Why not |
|---|---|
| `cupertino_icons` | We don't ship Cupertino chrome. |
| `flutter_animate` / `lottie` | Animations are forbidden by the constitution. |
| `flutter_local_notifications` | No notifications in v1 (D-006). |
| `firebase_*` | Use drift; Supabase is the eventual sync option, not Firebase. |
| `provider`, `bloc`, `get`, `mobx` | Pick one state lib (Riverpod). |
| `flutter_secure_storage` | No secrets to store in v1. Reintroduce with sync (Phase 11). |

---

## 4. Logic-layer specifics

### Command parser (`domain/commands.dart`)

Sealed class hierarchy. Each command is a case:

```dart
sealed class Command {
  const Command();
}

final class CheckHabit extends Command {
  final int id;
  const CheckHabit(this.id);
}

final class GoToView extends Command {
  final ViewName view;
  const GoToView(this.view);
}

// ... etc.

Command? parseCommand(String input);  // null = unknown
```

The parser is pure Dart, fully unit-tested, and shared by:
- Desktop command palette (string in → `Command` out → dispatched as `Intent`).
- Mobile button grid (button tap → constructs the `Command` directly).

See [input_spec.md](input_spec.md) for the full grammar.

### Streak engine (`domain/streaks.dart`)

Pure functions. Inputs: `Habit`, list of `Completion`, today's date. Outputs: current streak, longest streak, shield count. Algorithm in [data_model.md](data_model.md) §6.

### Schedule resolver (`domain/schedule.dart`)

Pure function: `bool isHabitDueOn(Habit habit, DateTime day)`. Centralizes weekly/custom-days logic so views and streaks agree on "what was due today."

---

## 5. State layer (`state/`)

Riverpod providers, organized by domain:

```
state/
  daily_provider.dart       // todays habits + completion state
  habits_provider.dart      // CRUD for habits (AsyncNotifier)
  stats_provider.dart       // computed: streaks, contribution grid data
  settings_provider.dart    // theme id, font size, font family
  vacation_provider.dart    // active vacation window
  command_provider.dart     // parses + dispatches commands
```

All async providers are `AsyncNotifier` or `AsyncValue`-typed. UI code handles `loading`/`error`/`data` exhaustively (no `.value!`).

---

## 6. Versioning posture

- Pin Flutter SDK in `pubspec.yaml` to a known-good minor.
- Pin all dependencies to their **caret major** (`^2.4.1`) — patch and minor updates are auto-resolved, majors require a spec amendment.
- Run `flutter pub upgrade --major-versions` quarterly, not ad hoc.

---

## 7. Testing posture

| Layer | Test type | Coverage target |
|---|---|---|
| `domain/` | Unit tests | 90%+ — these are pure functions, easy and load-bearing. |
| `data/` | Drift integration tests using in-memory DB | All migrations, all repository methods. |
| `state/` | Riverpod `ProviderContainer` tests | Critical flows (toggle habit, recompute streak). |
| `ui/` | Widget tests for Daily, Stats, NewHabit | Smoke + golden tests for splash and key views. |
| End-to-end | `integration_test` package, manual on each platform | One scripted flow per phase exit. |

Goldens: only for Splash and DailyView (empty + populated states). Don't golden-test every widget; that produces noise.
