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

**Completed: 2026-05-08**

**Goal:** a usable daily habit tracker on macOS. You can create habits, see them today, check them off, and the streak count is correct tomorrow.

### Scope
- Drift schema per [data_model.md](data_model.md) §1: `Habits`, `Completions`, `Groups`, `Settings`, `Vacations`.
- Migration v1 (the initial schema).
- Repositories for habits and completions.
- `HabitsNotifier`, `DailyNotifier` Riverpod providers.
- Three-pane layout (Sidebar | Main | Inspector). Inspector can be a stub showing "no selection."
- `DailyView` with prompt line, week strip, habit groups, habit rows.
  - Tap to toggle completion (checkbox tracking type only in this phase).
- `NewHabitDialog` — checkbox tracking type only. Other types (count, number, health) show as disabled in this phase.
- Streak engine for checkbox habits. Display in habit row + inspector.
- Sidebar nav: Daily / Stats (stub) / Profile (stub).
- Status bar with view name + version.
- Day navigation: `selectedDayProvider`, week-strip arrows + day tap; toggle and habit-list filtering respect selected day.
- Basic command palette stub (`⌘K`) and habit-row j/k keyboard navigation.

### Exit criteria
- [x] Create 5 habits in 3 groups; check 3 of them; quit and relaunch — state restored.
- [x] Streak count increments correctly the day after a check; resets the day after a miss.
- [x] Schedule honored: a "weekdays only" habit doesn't show on Saturday.
- [x] All `domain/` unit tests pass with ≥90% coverage.
- [x] No Material ripples visible anywhere; tap a habit row, no animation beyond a 1-frame opacity flash.
- [x] App data lives at `~/Library/Application Support/TerminalHabits/db.sqlite`.

### Out of scope
- Stats view, vacation, settings dialog, full command palette, count/number/health tracking types, habit editing, schedule history.

---

## Phase 2 — UI refinement: header, week strip, group polish (≈ 1 week)

**Completed: 2026-05-08**

**Goal:** the daily view matches the visual baseline in `design_spec.md` §UI-mockup. Header behaves like a real terminal output, the week strip is informative at a glance, and groups feel terminal-native.

### Scope
- **Sidebar nav** stays as the primary view switcher on desktop (Phase 1 layout retained). The active item is marked with a left-side amber `▸` indicator. The earlier idea of a top tab bar in `WindowChrome` was tried and reverted — it duplicated the sidebar without adding value. `WindowChrome` keeps its plain title + version meta.
- **Daily view header** (in order, top to bottom):
  - `{userName}@TerminalHabits $ daily` — terminal prompt line. `userName` comes from the `settings.userName` row via `userNameProvider`.
  - `// {N} completions. {dynamic motivational comment}` — comment line; copy is bucketed by completion count.
  - `📆 {Weekday}, {Month} {Day} {Year}` — calendar icon + selected-day label.
  - `🔥 {maxCurrentStreak} days * 🛡 {sumShields}` — aggregate streak/shield summary computed across all active habits (not just ones due on the selected day).
- **Week strip** redesign:
  - Day-of-week labels above day numbers (`Mon` / `23`).
  - Selected day prefixed with `*` and rendered with `TH.bg3` background.
  - Below each day cell: a thin completion-intensity bar — width proportional to `completionsThatDay / habitsDueThatDay` (clamped 0..1), rendered with `TH.amber`. Driven by a new `weeklyRatiosProvider`.
  - `<` / `>` arrows on either side, week-stride navigation.
- **Habit groups**:
  - Collapsible chevron `▾` (open) / `▸` (closed); state persists via `groups.collapsed`.
  - Header shows `[done/total]` count, flipped to green when all done.
  - Optional comment annotation (`// after waking up`) surfaced from a new `groups.note` text column.
  - **Group CRUD**: `NewHabitDialog` gets a `Group` dropdown with an inline `+ new` amber pill that opens a name prompt and creates the group on the spot. Right-click / long-press on a group header → menu (`rename`, `edit note`, `delete`). Delete with affected habits opens a reassign-or-cascade radio dialog.
- **Habit rows**:
  - Inline streak `🔥 N` aligned to the right of the habit name.
  - Optional clock annotation `🕒 HH:mm` if `habits.target_time` is set.
  - Sub-comment line (`// note text`) below the row when `habits.note` is set.
- **Inspector decoupling**: inspector now resolves the focused habit from the unfiltered `habitsProvider` and recomputes streaks fresh, instead of looking it up inside `dailyState.groups` (which is filtered to "due-on-selected-day"). This keeps the focused habit visible regardless of day navigation, and prevents drift between the row's streak and the inspector's streak.

### Schema changes
- Migration v2: add `groups.note TEXT NULL`, `habits.target_time TEXT NULL` (HH:mm string in 24-hour). `onUpgrade` uses `m.addColumn` for non-destructive migration of existing v1 databases.

### Exit criteria
- [x] Sidebar shows the active view with the amber `▸` indicator; ⌘1/2/3 still switches views.
- [x] Header renders prompt, comment, calendar date, and aggregate streak summary; values reflect `selectedDayProvider` and `userNameProvider`.
- [x] Week strip intensity bars reflect `completed/due` ratios; ratio is recomputed when habits or completions change.
- [x] Collapsing a group hides its rows and persists across restart.
- [x] Habit row shows streak inline; clock + note annotations render when those columns are set.
- [x] Inspector "current" matches the row's `🔥 N` for the same focused habit, even when the habit isn't due on the selected day.
- [x] No regressions from Phase 1.

### Out of scope
- Habit editing UX, start dates, schedule history (Phase 3 / Phase 5).
- Stats view, vacation, settings dialog.

---

## Phase 3 — Habit editing & start date (≈ 1 week)

**Completed: 2026-05-09**

**Goal:** any habit field is editable from the UI. Habits respect a start date, so back-dated views don't show habits that didn't exist yet.

### Scope
- **Right-click on habit row** (PC) and **long-press** (mobile stub) → context menu (`edit`, `archive`, `delete`) via `habit_menu.dart`.
- **`EditHabitDialog`**: name, group (dropdown with inline `+ new`), schedule, color, icon, note, startDate (date picker), targetTime (HH:mm picker). Tracking type read-only when completions exist.
- **Schedule change warning**: shown only when completions exist on days dropped by the new schedule. Overwrites without history (history preserved in Phase 5).
- **Start date enforcement**: `dailyStateProvider` filters habits by `selectedDay >= habit.startDate`; streak engine walks from `min(habit.startDate, oldest_completion)`.
- **`NewHabitDialog`** gains a `defaultStartDate` parameter: the `[ + new habit ]` button in the daily view passes `selectedDay`; ⌘N and the command palette pass nothing (defaults to `DateTime.now()`).
- **Archive flow**: sets `archivedAt`; archived habits removed from daily view but preserved in DB.
- **Delete flow**: confirmation dialog, cascades to completions.
- **Archive view** (`archive_view.dart`): listed in sidebar under the existing nav items; shows archived habits with relative archive time, restore and delete actions.
- **`[ + new habit ]` button** moved from sidebar to the bottom of the daily-view habit list. On mobile (empty day) it also appears at the top. On desktop (empty day) only a text hint (`press ⌘N`) is shown.

### Schema changes
- Migration v3: `ALTER TABLE habits ADD COLUMN start_date DATETIME NOT NULL DEFAULT '…'`, then `UPDATE habits SET start_date = created_at`.

### Exit criteria
- [x] Right-click on a habit row opens the context menu; selecting `edit` opens `EditHabitDialog` populated with current values.
- [x] Saving the dialog persists changes immediately; UI updates without restart.
- [x] A habit with `startDate` 7 days ago does not appear when navigating to a day older than that.
- [x] Archive removes habit from daily view; delete removes it everywhere (with confirmation).
- [x] All Phase 1 / Phase 2 features still work.

### Out of scope
- "Keep old progress" prompt for schedule changes (Phase 5).
- Tracking-type changes when completions exist (Phase 5 once history exists).

---

## Phase 4 — Icons, tracking types, group notes (≈ 1 week)

> After user verification, add `**Completed:** YYYY-MM-DD` here and tick all checkboxes below. Then commit per `constitution.md §7`.

**Goal:** habits and groups show Lucide icons with color; tracking type (checkbox / counter / duration) is selectable at creation; count and elapsed time surface in the row next to the streak flame.

### Scope
- **Lucide icon picker** (`IconPickerDialog`): full-screen dialog with a search field and a scrollable grid of ~90 curated icons organised by category (`productivity`, `health`, `mind`, `creative`, `social`, `home`, `misc`). Source list lives in `lib/theme/icon_library.dart`. Each entry maps a string key (stored in `habits.icon` / `groups.icon`) to a `LucideIcons` `IconData`. Replaces the bare text field in `NewHabitDialog` and `EditHabitDialog`. A `[ text ]` fallback lets the user type 1–2 chars for any glyph not in the picker.
- **Group icons**: `groups.icon TEXT NULL` (migration v4). Same picker reused in `NewGroupDialog` and the group context menu `edit icon` option. Group header renders the icon next to the name, colored `TH.fgDim`. `null` renders no icon slot.
- **Group header layout change**: collapse chevron (`›` / `⌄`) moved to the far right, after `[done/total]` count.
- **Group notes at creation**: `NewGroupDialog` (replaces bare `promptText` call) includes both a name field and an optional note field. The existing `edit note` menu option is retained.
- **Tracking types in `NewHabitDialog`**: after choosing name/group/schedule, a new `type` pill row offers `checkbox`, `counter`, `duration`. Selecting a type reveals its extra field:
  - `counter` → integer `target` field (label: `min count`, e.g. `10`).
  - `duration` → integer `target` field (label: `target (min)`, e.g. `30`).
  - These write to `habits.tracking`, `habits.target`, and `habits.unit` (`null` / `null` / `reps` / `min`).
- **Tracking display in habit row**: for `counter` and `duration` habits, show `value/target` (or `valuemin/targetmin`) to the right of the flame when `todayCompletion != null`. Tapping the checkbox area increments the value by `+1` (counter) or `+5` (duration, minutes); once `value >= target` the row reads as done. `isDoneToday` updated to reflect target-based completion.
- **Lucide flame icon**: replace the `🔥` text emoji in `HabitRow` and the daily-view header with `LucideIcons.flame` rendered as a Flutter `Icon`.

### Schema changes
- Migration v4: `ALTER TABLE groups ADD COLUMN icon TEXT NULL`. No backfill — null renders without an icon slot.

### Exit criteria
- [ ] Icon picker opens from a `[ pick icon ]` button in `NewHabitDialog` and `EditHabitDialog`; searching narrows the grid live.
- [ ] Selecting an icon shows a live preview of the icon+color combination in the dialog before save.
- [ ] Habit row renders the Lucide icon in the habit's color; old `●` habits display as text fallback.
- [ ] Group header shows the group icon (if set) before the name; collapse chevron is on the far right.
- [ ] Creating a group via `[ + new ]` in the habit dialog opens `NewGroupDialog` with name + note fields.
- [ ] `counter` and `duration` tracking types are selectable in `NewHabitDialog`; their targets save correctly.
- [ ] Row shows `value/target` for counter/duration; tapping increments; done state reflects target.
- [ ] Flame in habit row and daily header is a Lucide `Icon`, not an emoji.
- [ ] No regressions from Phases 1–3.

### Out of scope
- Color palette expansion beyond the current 6 (Phase 6 settings dialog).
- Schedule history / progress preservation (Phase 5).
- Full touch-friendly counter/duration input (Phase 10).

---

## Phase 5 — Schedule history & progress preservation (≈ 1.5 weeks)

> After user verification, add `**Completed:** YYYY-MM-DD` here and tick all checkboxes below. Then commit per `constitution.md §7`.

**Goal:** changing a habit's schedule or tracking type can preserve past completion validity. A daily-then-weekend habit shows correctly on weekdays before the change and weekends after.

### Scope
- **New table** `habit_schedule_history`:
  - `id INTEGER PK`, `habit_id INTEGER FK`, `effective_from DATETIME (UTC midnight)`, `schedule TEXT (JSON)`, `tracking TEXT`, `created_at DATETIME`.
  - Index on `(habit_id, effective_from DESC)` for the lookup query.
- **Insert-on-create**: when a habit is created, also insert one history row with `effective_from = start_date` and the current schedule + tracking.
- **Edit dialog flow**: when the user changes `schedule` or `tracking` and saves, the dialog prompts:
  > Keep progress for past days?
  > [ keep history ] applies the new schedule from today forward; old completions stay valid on the days they were due.
  > [ overwrite ] replaces the schedule retroactively for all dates.
  - **keep history** → insert a new history row with `effective_from = today_utc`. Older rows untouched.
  - **overwrite** → delete all history rows; insert a single row with `effective_from = start_date` and the new values.
- **Lookup helper** `effectiveScheduleAt(habitId, dayUtc)` returns the most recent history row with `effective_from <= dayUtc`.
- **Update `isHabitDueOn`** and **streak engine** to call `effectiveScheduleAt` per day instead of reading `habits.schedule` directly.
- **Inspector pane** gains a "schedule history" section listing entries with their effective dates.

### Schema changes
- Migration v4: create `habit_schedule_history`. On migration: for every existing habit, insert one row with `effective_from = habit.start_date`, `schedule = habit.schedule`, `tracking = habit.tracking`.
- Once the history table is the source of truth, `habits.schedule` and `habits.tracking` columns become **mirror columns** of the most-recent history row (kept for query convenience). Repository writes update both.

### Exit criteria
- [ ] Create a `daily` habit, log completions for a week, change to `weekends`, choose **keep history**: weekday completions remain visible and counted in streak; from the change date forward, the habit only appears Sat/Sun.
- [ ] Change a checkbox habit to count, choose **keep history**: old checkbox completions remain visible and counted as 1.
- [ ] Choosing **overwrite** wipes prior validity — past completions on no-longer-scheduled days disappear from the daily view.
- [ ] `dailyStateProvider` and the streak engine produce the same results as Phase 1 for habits whose schedule has never changed (regression check via existing tests, augmented with backfilled history rows).
- [ ] Inspector "schedule history" section lists entries with their effective dates.

### Out of scope
- Bulk schedule editing across multiple habits.
- Editing `start_date` after history rows exist (block in this phase).
- Surfacing schedule changes in stats view (Phase 7).

---

## Phase 6 — Settings & preferences (≈ 1 week)

> After user verification, add `**Completed:** YYYY-MM-DD` here and tick all checkboxes below. Then commit per `constitution.md §7`.

**Goal:** a real settings surface where the user can change appearance and tweak app behavior. Replaces ad-hoc `SharedPreferences` keys scattered across the codebase with a single typed settings layer.

### Scope
- **`SettingsDialog`** (opened via `Cmd+,` or command-palette `settings`):
  - **Appearance** group: theme switcher (6 themes), font size pills, font family preview cards. Theme switching is instant, no animation.
  - **Behavior** group:
    - `allowFutureMarking` (bool, default `false`) — overrides the hard-disable from Phase 1. When `false`, tapping the checkbox on a future day shows the "[ understood ]" notice. When `true`, marking is permitted with no warning.
    - `minDailyCompletionPct` (int 0–100, default `60`) — the minimum percentage of due habits completed for a day to count as a "successful day" in stats and in the per-day shield system (see Backlog). Surfaces in the week-strip intensity bar and in stats grouping.
    - `firstDayOfWeek` (enum, default `monday`) — controls week strip layout and stats grouping.
    - `weekStartsAtMidnight` (bool, default `true`) — if false, "today" rolls over at a user-chosen hour (e.g. 4 AM for night-owls). Affects `localMidnightUtc` semantics.
    - `confirmDestructive` (bool, default `true`) — show confirms for archive/delete (delete is always confirmed; archive becomes silent if false).
  - **About** group: version, build mode, data location, "view memory" link to the data file.
- **Settings persistence**: introduce a `SettingsRepository` backed by the existing `app_settings` Drift table (already in schema). All bool/string prefs migrate from `SharedPreferences` to this table over the course of the phase. `SharedPreferences` is then reserved for first-run flags only (`seenSplash`, `seenOnboarding`).
- `settingsProvider` (Riverpod `AsyncNotifier`) exposes the settings record; UI watches it and writes back through the notifier.
- `Cmd+,` keyboard shortcut wired on macOS / Linux. The command palette's "settings" command opens the same dialog.
- Inspector pane shows nothing about settings (settings are global, not selection-scoped).

### Schema changes
- No table changes. The existing `settings (key TEXT PK, value TEXT)` table is reused; the repository typecasts on read.

### Exit criteria
- [ ] Settings dialog opens via `Cmd+,` and via the command palette.
- [ ] Switching theme updates colors instantly across all visible widgets without restart.
- [ ] Setting `allowFutureMarking = true` permits checkbox toggles on future days; `false` (default) keeps the "[ understood ]" notice.
- [ ] All settings persist across app restart.
- [ ] Old `SharedPreferences`-backed settings (e.g. `warnFutureToggle`) are migrated to the `settings` table on first launch after the upgrade.

### Out of scope
- Per-habit settings (those live in the edit dialog from Phase 3).
- Stats view, command palette polish, vacation mode, count/number tracking — all in Phase 7.

---

## Phase 7 — macOS Polish: stats, command palette, vacation, tracking types (≈ 2.5 weeks)

> After user verification, add `**Completed:** YYYY-MM-DD` here and tick all checkboxes below. Then commit per `constitution.md §7`.

**Goal:** the Mac app feels complete. All remaining features in `feature_spec.md` work on macOS.

### Scope
- `StatsView` blocks: Overview, Streaks, Rates, Contributions (custom-painted), DayOfWeek bars.
- `Sparkline` widget (custom-painted).
- `ContributionGrid` widget (custom-painted, 5 levels of green via `Color.lerp`). Honors schedule history.
- `VacationView` with palm-tree ASCII + extend/end actions.
- `CommandPalette` polish: filter + arrow-nav + Enter dispatches; expand command set to include vacation, settings, archive, edit-focused.
- Keyboard shortcuts wired per [input_spec.md](input_spec.md):
  - `Cmd+V` vacation (settings already delivered in Phase 6).
  - `space` to toggle focused habit row.
- Tracking types: count, number, duration (`HH:mm` or `Nm` accumulator with target). (`health` still stubbed on Mac per D-007.)
- Inspector pane content per current view.

### Exit criteria
- [ ] Command palette opens in <50 ms, filters live, Enter dispatches.
- [ ] All keyboard shortcuts in `input_spec.md` table work.
- [ ] Stats view contributions grid renders 365 days correctly across DST boundaries and across schedule-history changes.
- [ ] Vacation mode pauses streak decay (verified by test).
- [ ] No regressions from Phases 1–5.

### Out of scope
- Linux build, Android build, sync.

---

## Phase 8 — Per-day shield system (≈ 1.5 weeks)

> After user verification, add `**Completed:** YYYY-MM-DD` here and tick all checkboxes below. Then commit per `constitution.md §7`.

**Goal:** replace the per-habit shield counter (Phase 1) with a per-day shield concept that acts as a real recovery mechanism. A shielded day counts as a successful day for streak purposes whether you applied the shield manually, the system auto-applied one at end-of-day, or you back-filled the day to clear it on its own.

### Scope
- **New table** `day_shields(id INTEGER PK, day DATETIME UNIQUE, source TEXT, applied_at DATETIME)`.
  - `day` is UTC-midnight-of-local-day (same convention as `completions.day`).
  - `source` ∈ `{'manual', 'auto'}`.
  - `UNIQUE` on `day` so a single day can hold at most one shield.
- **Day-success definition** (depends on Phase 6 settings):
  - A day is *successful* when `dailyCompletionPct(day) >= minDailyCompletionPct` OR a row in `day_shields` exists for that day.
  - `dailyCompletionPct(day)` = `dueAndCompleted(day) / dueOnDay(day)` (vacation days excluded).
- **Streak engine** is rewritten around day-success rather than per-habit completion. The new walker:
  - Iterates from `min(habit.start_date, oldest completion)` to today (per-habit walk is replaced with a single per-day walk because shields are global).
  - Skips non-due days (no habit due) and vacation days.
  - For each "active" day: success → run++, miss → run = 0.
  - Per-habit streaks become *derived* (consecutive completed-due days for that habit, with no shield logic).
- **Shield earning**: every N consecutive successful days earns 1 shield to the available pool. `N` defaults to 7, configurable in settings (`shieldEarnInterval`). Earned shields live in a single `available_shields` counter (kept in `settings`).
- **Manual apply / remove**: right-click on a day cell in the week strip → menu (`apply shield`, `remove shield`). On Android, long-press. Removing returns the shield to the available pool. Applying to a future day is allowed (planned travel).
- **Auto-apply at end-of-day**: at app launch, scan all calendar days from the last-seen date to yesterday. For each:
  - If success without shield → no-op.
  - If miss and `available_shields > 0` → insert `day_shields(day, 'auto', now)` and decrement available pool.
  - If miss and no shields → leave as miss (streak breaks normally).
- **Auto-recovery**: when `dailyCompletionPct(day) >= min` for a day that has a `source='auto'` shield, the shield is released (row deleted, available pool incremented). Triggered by the same launch-scan and by any completion write that touches a previously-shielded day.
- **UI surfacing**:
  - Week-strip day cell renders a small `🛡` overlay when the day has a shield (color differs by `source`: amber for manual, dim for auto).
  - Aggregate header reads `🛡 {available}` (the pool), not the old per-habit count.
  - Inspector pane on a day-cell focus shows `applied_at` and `source`.
- **Migration cleanup**:
  - Drop the per-habit `StreakResult.shields` field (or keep it set to 0 for compatibility while UI moves over).
  - Old habit-row `🛡 N` annotation is removed.

### Schema changes
- Migration v5: create `day_shields`. Add `available_shields` row to `settings` initialized to 0. Add `shieldEarnInterval` setting (default 7).

### Exit criteria
- [ ] Right-click a past day in the week strip → "apply shield"; the day's intensity bar gets a 🛡 overlay and the streak immediately recomputes through it.
- [ ] Right-click again → "remove shield"; shield returns to the pool, streak recomputes without it.
- [ ] Apply a shield to a future day; on the day itself, that shield holds even if no habits are completed.
- [ ] Quit at end of day after a partial day (below `minDailyCompletionPct`) with shields available; relaunch next day → yesterday auto-shielded, banner notifies.
- [ ] Back-fill an auto-shielded day to clear the threshold → shield auto-returns to pool.
- [ ] Per-habit streak still computes correctly without shield interaction.
- [ ] No regressions in Phases 1–6.

### Out of scope
- Earning shields by manual purchase or vacation conversion (Backlog).
- Multiple shields per day.
- Removing a shield from a past day that's load-bearing for a multi-week streak: allowed, the streak just breaks. No special warning in this phase.

---

## Phase 9 — Linux parity (≈ 1.5 weeks)

> After user verification, add `**Completed:** YYYY-MM-DD` here and tick all checkboxes below. Then commit per `constitution.md §7`.

**Goal:** a `.deb` (and a tarball) that runs on Ubuntu 22.04+ with feature parity to macOS Phase 7.

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
- [ ] Same feature set as Phase 7 works on Linux (run the same manual test script).
- [ ] System tray icon present and functional.
- [ ] App launches under both Wayland and X11 sessions.

### Out of scope
- Snap/Flatpak distribution (deferred). RPM (deferred).

---

## Phase 10 — Android adaptation (≈ 4 weeks)

> After user verification, add `**Completed:** YYYY-MM-DD` here and tick all checkboxes below. Then commit per `constitution.md §7`.

**Goal:** a `.apk` that delivers the same habit-tracking experience via touch, with the same visual aesthetic.

This phase is the largest UX shift. See [input_spec.md](input_spec.md) §3 for the full mobile interaction model and [design_spec.md](design_spec.md) §6 for the layout breakpoint behavior.

### Scope
- Single-pane layout under `LayoutBuilder` breakpoint `<720px`:
  - Bottom tab bar (Daily / Stats / Profile, 3 tabs) replaces the desktop sidebar on phones; tablets in landscape may keep the sidebar.
  - Inspector content collapses into bottom-sheet drawer, opened via swipe-up or button.
  - Window chrome and status bar are hidden; system status bar styled to match.
- `MobileCommandBridge`: a `GridView` of bordered command buttons that replaces the command palette. Buttons dispatch the same `Intent`s as the desktop palette.
- Touch affordances:
  - Tap target minimum 48dp.
  - Long-press → context menu (edit, archive) — promoted from Phase 3 stub.
  - Swipe-right on habit row → quick edit.
  - Haptic light impact on every button press.
- `health_connect` integration for the `[health]` tracking type (steps, sleep).
- Android theming: status bar color = `TH.bg`, navigation bar color = `TH.bg1`.
- Android app icon (monogram in `TH.green` on `TH.bg`).
- Permissions: only `ACCESS_FINE_LOCATION` if a habit needs it (out of scope v1); `BODY_SENSORS` for `health_connect`.

### Exit criteria
- [ ] `.apk` installs and runs on Android 7.0 (minSdk 21) and Android 14.
- [ ] Same feature set as Phases 5 + 6 works via touch only — no keyboard plugged in.
- [ ] One full week of dogfooding on a personal Android device with no critical bugs.
- [ ] Health Connect wires `[health]` habits to step count.
- [ ] `.apk` size under 30 MB.
- [ ] No regressions on macOS or Linux from the touch refactor.

### Out of scope
- iOS, Android tablets (deferred).
- Widgets, complications.
- Background sync, foreground services.

---

## Phase 11 — Optional cloud sync (post-1.0, deferred)

> After user verification, add `**Completed:** YYYY-MM-DD` here and tick all checkboxes below. Then commit and tag `v1.0.0` per `constitution.md §7`.

**Goal:** opt-in multi-device sync. User signs in once on each device; habits and completions converge.

### Scope (tentative)
- Supabase project: `auth.users`, mirror tables for `habits`, `completions`, `groups`, `vacations`, `settings`, `habit_schedule_history`.
- `SyncRepository` layer between `state/` and `data/`. Local writes are authoritative; sync is async.
- Conflict resolution: last-write-wins per row, with a "last edited" timestamp column.
- Sign-in UI in Settings; sign-out clears remote credentials but preserves local DB.
- Manual "force pull" / "force push" controls for recovery.

### Exit criteria
- [ ] Two devices stay in sync within 5 seconds of online activity.
- [ ] Going offline doesn't block any local action.
- [ ] Coming back online reconciles divergent edits without duplication.
- [ ] Sign-out leaves the device fully usable in local-only mode.

### Triggers to start Phase 11
- Real user request for multi-device.
- Phases 1–7 stable for at least 1 month.

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

---

## Backlog (unphased)

Ideas that are committed to ship eventually but not yet slotted into a phase. Promote to a numbered phase when prioritized; renumber subsequent phases as needed.

### Other unphased ideas
- Bulk import / export (`.json`).
- Habit templates ("morning routine pack").
- Per-habit reminders (revisit D-006 — only with explicit opt-in toggle).
