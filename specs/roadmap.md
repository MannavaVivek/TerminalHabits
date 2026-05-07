# Roadmap — TerminalHabits

> Phased delivery plan. Each phase ships a runnable, dogfoodable build before the next begins. Phase order is fixed: macOS → Linux → Android. Cloud sync is a deferred post-1.0 phase.

---

## Phase 0 — Bootstrap (≈ 1 week)

**Completed: 2026-05-07**

**Goal:** an empty-but-themed Flutter desktop app that boots on macOS into the splash screen and accepts no input besides "click to onboard."

### Scope
- Initialize Flutter project: `flutter create --platforms=macos,linux,android terminal_habits`.
- Create folder structure per [tech_stack.md](tech_stack.md) §2.
- Add core dependencies (`flutter_riverpod`, `google_fonts`, `window_manager`, `shared_preferences`).
- Wire root `MaterialApp` with `ThemeData.dark()` + JetBrains Mono + `splashFactory: NoSplash.splashFactory`.
- Implement `theme/tokens.dart` with the Matrix palette from [design_spec.md](design_spec.md).
- Implement `WindowChrome` (frameless, custom titlebar with traffic lights) on macOS only.
- Implement `SplashView` (ASCII logo + cursor blink + tap-to-onboard hint).
- Implement `OnboardingView` as a stub (4 empty steps, "skip" button).
- No persistence layer yet beyond `shared_preferences` for `seenSplash`.

### Notes
- JetBrains Mono bundled locally (`assets/fonts/`) with `GoogleFonts.config.allowRuntimeFetching = false`. macOS sandbox blocks outgoing TCP without the network entitlement; bundling avoids the dependency entirely and is consistent with local-first policy.
- `freezed` and `drift` deferred to Phase 1 when models and DB are first needed.

### Exit criteria
- [x] `flutter run -d macos` shows the frameless window with the traffic lights and centered ASCII logo.
- [x] Clicking "yours to shape." pushes onboarding and sets `seenSplash=true`.
- [x] Window minimum size is enforced at 1080×680.
- [x] App launches in under 1.5s on a 2020+ MacBook.
- [x] `flutter analyze` clean, `flutter test` passes (even with one trivial test).

### Out of scope
- Linux build, Android build, any habit features.

---

## Phase 1 — macOS MVP: Daily view + habits CRUD (≈ 3 weeks)

> After user verification, add `**Completed:** YYYY-MM-DD` here and tick all checkboxes below. Then commit per `constitution.md §7`.

**Goal:** a usable daily habit tracker on macOS. You can create habits, see them today, check them off, and the streak count is correct tomorrow.

### Scope
- Drift schema per [data_model.md](data_model.md) §1: `Habits`, `Completions`, `Groups`, `Settings`, `Vacations`.
- Migration v1 (the initial schema).
- Repositories for habits and completions.
- `HabitsNotifier`, `DailyNotifier` Riverpod providers.
- Three-pane layout (Sidebar | Main | Inspector). Inspector can be a stub showing "no selection."
- `DailyView` with prompt line, week strip, habit groups, habit rows.
  - Tap to toggle completion (checkbox tracking type only in this phase).
  - Long-press → context menu (edit, archive).
- `NewHabitDialog` — checkbox tracking type only. Other types (count, number, health) show as disabled in this phase.
- Streak engine for checkbox habits. Display in habit row + inspector.
- Sidebar nav: Daily / Stats (stub) / Profile (stub).
- Status bar with view name + version.

### Exit criteria
- [ ] Create 5 habits in 3 groups; check 3 of them; quit and relaunch — state restored.
- [ ] Streak count increments correctly the day after a check; resets the day after a miss.
- [ ] Schedule honored: a "weekdays only" habit doesn't show on Saturday.
- [ ] All `domain/` unit tests pass with ≥90% coverage.
- [ ] No Material ripples visible anywhere; tap a habit row, no animation beyond a 1-frame opacity flash.
- [ ] App data lives at `~/Library/Application Support/TerminalHabits/db.sqlite`.

### Out of scope
- Stats view, vacation, settings dialog, command palette, count/number/health tracking types.

---

## Phase 2 — macOS Polish: stats, command palette, settings (≈ 3 weeks)

> After user verification, add `**Completed:** YYYY-MM-DD` here and tick all checkboxes below. Then commit per `constitution.md §7`.

**Goal:** the Mac app feels complete. All features in `feature_spec.md` work on macOS.

### Scope
- `StatsView` blocks: Overview, Streaks, Rates, Contributions (custom-painted), DayOfWeek bars.
- `Sparkline` widget (custom-painted).
- `ContributionGrid` widget (custom-painted, 5 levels of green via `Color.lerp`).
- `VacationView` with palm-tree ASCII + extend/end actions.
- `SettingsDialog`: theme switcher (6 themes), font size pills, font preview cards.
- `CommandPalette` (`Cmd+K` / `:`): filter + arrow-nav + Enter dispatches.
- Keyboard shortcuts wired per [input_spec.md](input_spec.md):
  - `Cmd+1/2/3` view switch, `Cmd+N` new habit, `Cmd+V` vacation, `Cmd+,` settings.
  - `j/k`/arrow + `space` for habit row navigation in DailyView.
- Tracking types: count, number. (`health` still stubbed on Mac per D-007.)
- Inspector pane content per current view.
- Theme switching (instant, no animation).

### Exit criteria
- [ ] All 6 themes selectable and persist across restarts.
- [ ] Command palette opens in <50 ms, filters live, Enter dispatches.
- [ ] All keyboard shortcuts in `input_spec.md` table work.
- [ ] Stats view contributions grid renders 365 days correctly across DST boundaries.
- [ ] Vacation mode pauses streak decay (verified by test).
- [ ] No regressions from Phase 1.

### Out of scope
- Linux build, Android build, sync.

---

## Phase 3 — Linux parity (≈ 1.5 weeks)

> After user verification, add `**Completed:** YYYY-MM-DD` here and tick all checkboxes below. Then commit per `constitution.md §7`.

**Goal:** a `.deb` (and a tarball) that runs on Ubuntu 22.04+ with feature parity to macOS Phase 2.

### Scope
- Linux build setup (clang, ninja, GTK 3, libsqlite3-dev).
- Verify frameless window works under both X11 and Wayland.
- Adapt keyboard shortcut modifier: `Cmd` on macOS → `Ctrl` on Linux. Use `defaultTargetPlatform`.
- Linux system tray icon (`tray_manager`): show/hide window from tray, quick-add menu.
- Packaging: `flutter_distributor` to produce `.deb` and `.tar.gz`.
- Verify clipboard, file picker, and font rendering on Linux.

### Exit criteria
- [ ] `flutter build linux --release` produces a working binary.
- [ ] `.deb` installs cleanly on Ubuntu 22.04 LTS (tested in VM).
- [ ] Same feature set as Phase 2 works on Linux (run the same manual test script).
- [ ] System tray icon present and functional.
- [ ] App launches under both Wayland and X11 sessions.

### Out of scope
- Snap/Flatpak distribution (deferred). RPM (deferred).

---

## Phase 4 — Android adaptation (≈ 4 weeks)

> After user verification, add `**Completed:** YYYY-MM-DD` here and tick all checkboxes below. Then commit per `constitution.md §7`.

**Goal:** a `.apk` that delivers the same habit-tracking experience via touch, with the same visual aesthetic.

This phase is the largest UX shift. See [input_spec.md](input_spec.md) §3 for the full mobile interaction model and [design_spec.md](design_spec.md) §6 for the layout breakpoint behavior.

### Scope
- Single-pane layout under `LayoutBuilder` breakpoint `<720px`:
  - Bottom tab bar replaces sidebar (Daily / Stats / Profile, 3 tabs).
  - Inspector content collapses into bottom-sheet drawer, opened via swipe-up or button.
  - Window chrome and status bar are hidden; system status bar styled to match.
- `MobileCommandBridge`: a `GridView` of bordered command buttons that replaces the command palette. Buttons dispatch the same `Intent`s as the desktop palette.
- Touch affordances:
  - Tap target minimum 48dp.
  - Long-press → context menu (edit, archive).
  - Swipe-right on habit row → quick edit.
  - Haptic light impact on every button press.
- `health_connect` integration for the `[health]` tracking type (steps, sleep).
- Android theming: status bar color = `TH.bg`, navigation bar color = `TH.bg1`.
- Android app icon (monogram in `TH.green` on `TH.bg`).
- Permissions: only `ACCESS_FINE_LOCATION` if a habit needs it (out of scope v1); `BODY_SENSORS` for `health_connect`.

### Exit criteria
- [ ] `.apk` installs and runs on Android 7.0 (minSdk 21) and Android 14.
- [ ] Same feature set as Phase 2 + 3 works via touch only — no keyboard plugged in.
- [ ] One full week of dogfooding on a personal Android device with no critical bugs.
- [ ] Health Connect wires `[health]` habits to step count.
- [ ] `.apk` size under 30 MB.
- [ ] No regressions on macOS or Linux from the touch refactor.

### Out of scope
- iOS, Android tablets (deferred).
- Widgets, complications.
- Background sync, foreground services.

---

## Phase 5 — Optional cloud sync (post-1.0, deferred)

> After user verification, add `**Completed:** YYYY-MM-DD` here and tick all checkboxes below. Then commit and tag `v1.0.0` per `constitution.md §7`.

**Goal:** opt-in multi-device sync. User signs in once on each device; habits and completions converge.

### Scope (tentative)
- Supabase project: `auth.users`, mirror tables for `habits`, `completions`, `groups`, `vacations`, `settings`.
- `SyncRepository` layer between `state/` and `data/`. Local writes are authoritative; sync is async.
- Conflict resolution: last-write-wins per row, with a "last edited" timestamp column.
- Sign-in UI in Settings; sign-out clears remote credentials but preserves local DB.
- Manual "force pull" / "force push" controls for recovery.

### Exit criteria
- [ ] Two devices stay in sync within 5 seconds of online activity.
- [ ] Going offline doesn't block any local action.
- [ ] Coming back online reconciles divergent edits without duplication.
- [ ] Sign-out leaves the device fully usable in local-only mode.

### Triggers to start Phase 5
- Real user request for multi-device.
- Phases 1–4 stable for at least 1 month.

---

## Cross-phase quality gates

Every phase must pass these before being considered complete:

1. `flutter analyze --no-fatal-infos` clean.
2. `flutter test` green.
3. Manual smoke script (per phase) executed and notes filed in `specs/_phase_logs/phase_N.md` (create as needed).
4. No new dependency added without a Decision Log entry in `constitution.md`.
5. Spec files updated in the same PR if behavior changed.

## Velocity assumptions

The week estimates above assume one developer working on this part-time. Treat them as relative sizing, not commitments. The exit criteria are the hard contract; weeks are not.
