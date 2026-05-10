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
  - `🔥 {overallStreak} days * 🛡 {availableShields}` — overall day-wise streak: consecutive days where every due habit was completed (100%); shown in amber when today is on track, gray/dim when today is at risk. Shield count shows the available pool (always 0 until Phase 8).
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

**Completed: 2026-05-09**

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
- [x] Icon picker opens from a `[ pick icon ]` button in `NewHabitDialog` and `EditHabitDialog`; searching narrows the grid live.
- [x] Selecting an icon shows a live preview of the icon+color combination in the dialog before save.
- [x] Habit row renders the Lucide icon in the habit's color; old `●` habits display as text fallback.
- [x] Group header shows the group icon (if set) before the name; collapse chevron is on the far right.
- [x] Creating a group via `[ + new ]` in the habit dialog opens `NewGroupDialog` with name + note fields.
- [x] `counter` and `duration` tracking types are selectable in `NewHabitDialog`; their targets save correctly.
- [x] Row shows `value/target` for counter/duration; tapping opens value dialog; done state reflects target.
- [x] Flame in habit row and daily header is a Lucide `Icon`, not an emoji.
- [x] No regressions from Phases 1–3.

### Out of scope
- Color palette expansion beyond the current 6 (Phase 6 settings dialog).
- Schedule history / progress preservation (Phase 5).
- Full touch-friendly counter/duration input (Phase 10).

---

## Phase 5 — Schedule history, end date & progress preservation (≈ 1.5 weeks)

**Completed: 2026-05-09**

**Goal:** changing a habit's schedule preserves past completion validity. A daily-then-weekend habit shows correctly on weekdays before the change and weekends after. Habits can also be given an end date after which they stop appearing.

### Scope
- **New table** `habit_schedule_history`:
  - `id INTEGER PK`, `habit_id INTEGER FK`, `effective_from DATETIME (UTC midnight)`, `schedule TEXT (JSON)`, `tracking TEXT`, `created_at DATETIME`.
  - Index on `(habit_id, effective_from DESC, id DESC)` for deterministic tie-breaking.
- **Insert-on-create**: when a habit is created, also insert one history row with `effective_from = start_date` and the current schedule + tracking.
- **Edit dialog — destructive change warnings** (replaces the old Keep/Overwrite/Cancel prompt):
  - **Tracking type change** (when completions exist): red warning "all history will be cleared, irreversible" → Cancel / Proceed. Proceed deletes all completions and replaces schedule history.
  - **Schedule change** (without tracking-type change, when completions exist): behavior depends on overlap between old and new day sets:
    - *No overlap* (e.g. Weekdays ↔ Weekends): red warning that all completions will be deleted. Proceed clears all completions and replaces history.
    - *Contracting* (new days ⊂ old days, e.g. Daily → Weekdays): warning lists which days will be deleted ("Sat, Sun completions removed") and which are kept. Proceed deletes only completions on the removed days; adds a new history row with `effective_from = today_utc`.
    - *Expanding* (new days ⊃ old days, e.g. Weekdays → Daily): no data deleted; only a new history row is inserted. Warning explains that streak may appear to reset until the new days accumulate completions.
  - **Start date moved later** (no type/schedule change): warns about loss of completions before the new start date. Proceed deletes completions with `day < new_start_date`.
  - When no completions exist or the change does not affect data, save silently (no dialog).
- **End date** (`habits.end_date DATETIME NULL`): optional field in both `NewHabitDialog` and `EditHabitDialog`. When set:
  - Habit is hidden from the daily view on any day after the end date.
  - The streak walk stops at `min(today, end_date)` so past streaks are preserved.
  - The week strip ratios exclude the habit on days after the end date.
  - End date must be on or after start date (validated before save).
- **Lookup helper** `effectiveScheduleAt(List<HabitScheduleHistory> history, DateTime dayUtc)` — pure domain function, order-independent, returning the most recent history row with `effective_from <= dayUtc`; ties broken by `id DESC`.
- **Update `isHabitDueOn` call sites** and **streak engine** to call `effectiveScheduleAt` per day instead of reading `habits.schedule` directly.
- **Inspector pane** gains a "schedule history" section listing entries with their effective dates and a "ends" row when `end_date` is set.

### Schema changes
- Migration v5:
  - Create `habit_schedule_history` with an index on `(habit_id, effective_from)`.
  - `ALTER TABLE habits ADD COLUMN end_date DATETIME NULL`.
  - Backfill: `INSERT INTO habit_schedule_history SELECT id, start_date, schedule, tracking, CURRENT_TIMESTAMP FROM habits`.

### Exit criteria
- [x] Create a `daily` habit, log completions for a week, change to `weekdays`: Sat/Sun completions are deleted, Mon–Fri completions and streaks are preserved; from today forward the habit only appears Mon–Fri.
- [x] Change a `daily` habit to `weekends`: Mon–Fri completions deleted; Sat/Sun completions kept; streak is now weekend-only.
- [x] Change from `weekdays` to `weekends` (no overlap): all completions deleted, red "no overlap" warning shown.
- [x] Change `weekdays` to `daily` (expanding): all completions kept, new history row inserted, no data deleted.
- [x] Tracking-type change clears all completions after warning.
- [x] Setting an end date hides the habit from the daily view the day after; habit still appears on days before the end date.
- [x] Streak walk stops at end date; a habit with an end date in the past shows a fixed historic streak.
- [x] `dailyStateProvider` and the streak engine produce the same results as Phase 4 for habits whose schedule has never changed.
- [x] Inspector "schedule history" section lists all entries with their effective dates.

### Out of scope
- Tracking-type history (type resets completions when changed).
- Editing `start_date` after history rows exist.
- Surfacing schedule changes in stats view (Phase 7).

---

## Phase 6a — User auth & data isolation (≈ 1 week)

> After user verification, add `**Completed:** YYYY-MM-DD` here and tick all checkboxes below. Then commit per `constitution.md §7`.

**Goal:** multi-user local auth with full per-user data isolation. Habits, groups, and vacations are scoped to the logged-in user. Login and registration are required on every fresh launch.

### Scope

#### Users table & data isolation
- **New `users` table**: `id INTEGER PK autoincrement`, `username TEXT UNIQUE`, `display_name TEXT`, `password TEXT` (plaintext — Phase 11 replaces with hashed + Supabase), `created_at DATETIME`.
- **`user_id` column** added to `habits`, `groups`, and `vacations`. All read/write queries filter by the logged-in user's id. Completions and `habit_schedule_history` are implicitly isolated through their `habit_id` FK.
- **Migration v6**: create `users` table; add `user_id INTEGER NOT NULL DEFAULT 1` to habits/groups/vacations; seed a placeholder user `(id=1, username='dev', password='dev', display_name=existing userName setting)` so existing data is assigned to user 1 and remains accessible.
- Fresh install: no placeholder user; registration creates the first user and the default 'general' group.

#### Auth flow
- **`RegisterView`**: fields — display name, username, password, confirm password. No validation rules in this phase (any length, any characters). On submit: insert user row, create default 'general' group for that user, set `SharedPreferences.loggedInUserId`, update `currentUserIdProvider`, push `OnboardingView`.
- **`LoginView`**: fields — username, password. On match: set SharedPreferences + provider, push `AppScaffold`. On mismatch: inline red error, no lockout. Two footer links: `[ register ]` → `RegisterView`, `[ forgot password ]` → `ForgotPasswordView`.
- **`ForgotPasswordView`**: enter username → if found, display the plaintext password from the DB directly on screen. Prominent note: "this is a temporary local dev feature — Phase 11 will replace it with email recovery." Link back to `[ login ]`.
- **`SplashView._proceed()`** routing:
  1. Check `SharedPreferences.loggedInUserId`; verify user still exists in DB.
  2. If valid session → update `currentUserIdProvider` → `AppScaffold` (or `OnboardingView` if `seenOnboarding=false`).
  3. If no session, user count > 0 → `LoginView`.
  4. If no session, user count == 0 → `RegisterView`.
- **Log out**: available from `UserWindow` (Phase 6b). Clears `SharedPreferences.loggedInUserId`, resets `currentUserIdProvider` to 0, pushes `LoginView`.

#### Sidebar & nav restructure
- **User button** at the bottom of the left sidebar (replaces the `profile` nav item). Displays: `[${initial}] ${displayName}` in dim style. Tapping opens `UserWindow` as a dialog.
- **Archive** removed from sidebar nav. Temporarily accessible at Settings → Data (Phase 6b). For Phase 6a: archive nav item is just hidden; `ArchiveView` stays in the codebase but is unreachable from the UI until Phase 6b wires it into settings.
- Sidebar nav: Daily / Stats only. User button at bottom.

#### User window (`UserWindow`)
- Dialog opened from the user button.
- **Header**: `[ ⚙ settings ]` button top-right (stub — opens placeholder until Phase 6b).
- **Body**: `username:`, `display name:` (editable inline, saves on blur), `member since:`, `total completions:`, `current streak:`.
- **Footer**: `[ log out ]` button.

#### `currentUserIdProvider`
- `StateProvider<int>((ref) => 0)`. Set to the logged-in user's id after login/register. All stream providers (`habitsProvider`, `groupsProvider`, `vacationsProvider`) guard on `userId == 0` by returning `Stream.empty()`.

### Schema changes
- Migration v6: new `users` table; `user_id INTEGER NOT NULL DEFAULT 1` on habits/groups/vacations.

### Exit criteria
- [ ] Fresh install: splash → register → onboarding → daily view.
- [ ] Subsequent launch: splash → login → daily view. Wrong password shows inline red error.
- [ ] `[ forgot password ]`: enter username → plaintext password shown on screen.
- [ ] Habits, groups, and vacations created by user A are invisible when logged in as user B.
- [ ] User button in sidebar shows initial + display name; tapping opens `UserWindow`.
- [ ] `UserWindow` shows username, member since, total completions, current streak; display name editable.
- [ ] Log out → next launch shows `LoginView`.
- [ ] Existing pre-auth data (migration) assigned to dev/dev user and still visible after login.

### Out of scope
- Password hashing, email, OAuth — Phase 11.
- Settings dialog, archive in settings — Phase 6b.
- Stats view, vacation mode — Phase 7.

---

## Phase 6b — Settings dialog & archive relocation (≈ 1 week)

> After user verification, add `**Completed:** YYYY-MM-DD` here and tick all checkboxes below. Then commit per `constitution.md §7`.

**Goal:** a real settings surface; archive moved out of sidebar nav into settings; `Cmd+,` shortcut wired.

### Scope
- **`SettingsDialog`**: opened via `Cmd+,`, command palette `settings`, or the `[ ⚙ settings ]` button in `UserWindow` (replaces the Phase 6a stub).
  - **Appearance**: theme switcher (6 themes), font size pills, font family preview cards. Instant apply, no animation.
  - **Behavior**: `allowFutureMarking` (bool, default `false`), `minDailyCompletionPct` (int 0–100, default `100`), `firstDayOfWeek` (enum, default `monday`), `weekStartsAtMidnight` (bool, default `true`), `confirmDestructive` (bool, default `true`).
  - **Data**: archived habits list with restore / delete; export to JSON; import from JSON; DB file path (read-only).
  - **About**: version, build mode, note about local-only password display limitation.
- **`settingsProvider`** (`AsyncNotifier`) backed by the existing `settings (key TEXT PK, value TEXT)` Drift table. All bool/string prefs migrate from `SharedPreferences` here; `SharedPreferences` is reduced to `seenSplash` only.
- **`Cmd+,`** wired in `AppScaffold` shortcuts (macOS/Linux).
- **Archive**: `ArchiveView` embedded in `SettingsDialog` → Data tab. Sidebar nav has no archive entry.

### Schema changes
- No new tables. Typed setting keys added to the existing `settings` table.

### Exit criteria
- [ ] `SettingsDialog` opens via `Cmd+,`, command palette, and user window settings button.
- [ ] Theme and font size update instantly across all visible widgets.
- [ ] `allowFutureMarking = true` skips the future-day warning dialog.
- [ ] Archived habits listed under Settings → Data with restore and delete actions.
- [ ] All behavior settings persist across restart.

### Out of scope
- Per-user settings scoping (settings remain global in this phase).
- Stats, command palette polish, vacation — Phase 7.

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

**Goal:** add a shield pool that can absorb missed days in the overall day-wise streak. One shield covers one missed day regardless of how many habits were missed that day.

### Scope
- **New table** `day_shields(id INTEGER PK, day DATETIME UNIQUE, source TEXT, applied_at DATETIME)`.
  - `day` is UTC-midnight-of-local-day (same convention as `completions.day`).
  - `source` ∈ `{'manual', 'auto'}`.
  - `UNIQUE` on `day` so a single day can hold at most one shield.
- **One shield per day**: if any habits were incomplete on a given day, one shield is consumed from the pool — not one per missed habit. Vacation days do not consume shields.
- **Day-success definition**: a day is *successful* when all due habits are completed OR a row in `day_shields` exists for that day.
- **Overall streak engine update**: the existing `computeOverallStreak` walker treats a shielded day as outcome `1` (success) even if habits were missed.
- **Per-habit streaks** remain unchanged: consecutive completed-due days for that habit with no shield interaction.
- **Shield earning**: every N consecutive successful days earns 1 shield to the available pool. `N` defaults to 7, configurable in settings (`shieldEarnInterval`). Earned shields live in a single `available_shields` counter (kept in `settings`).
- **UI — habit row**: on a day where a shield was consumed and the habit was *not* completed, the flame icon for that habit is replaced by a shield icon. Multiple habits missed → all show shield icon, but only one shield was consumed total.
- **UI — pending / gray streak**: the gray pending streak (shown while today is still open) counts a shielded day as a successful day, same as a completed day.
- **Manual apply / remove**: right-click on a day cell in the week strip → menu (`apply shield`, `remove shield`). On Android, long-press. Removing returns the shield to the available pool. Applying to a future day is allowed (planned travel).
- **Auto-apply at end-of-day**: at app launch, scan all calendar days from the last-seen date to yesterday. For each missed day with `available_shields > 0`: insert `day_shields(day, 'auto', now)` and decrement available pool. If no shields → leave as miss.
- **Auto-recovery**: when a missed day is back-filled to 100% completion and it had a `source='auto'` shield, the shield row is deleted and the available pool is incremented. Triggered by the launch-scan and by any completion write.
- **Shield permanence on schedule edits**: if a habit's schedule is later changed so that a previously shielded day is no longer tracked, the shield is kept (not reclaimed). No logic to recover shields from retroactive edits.
- **UI surfacing**:
  - Week-strip day cell renders a `🛡` overlay when a shield was consumed.
  - Header reads `🛡 {available}` (available pool count).
  - Inspector pane on a day-cell focus shows `applied_at` and `source`.
- **Migration cleanup**: `StreakResult.shields` field is removed (currently always 0); `DailyState.availableShields` replaces it, backed by the settings row.

### Schema changes
- Migration (new version): create `day_shields`. Add `available_shields` row to `settings` initialized to 0. Add `shieldEarnInterval` setting (default 7).

### Exit criteria
- [ ] Right-click a past day in the week strip → "apply shield"; streak immediately recomputes through it as a success.
- [ ] Right-click again → "remove shield"; shield returns to pool, streak recomputes without it.
- [ ] On a day where any habit was missed and a shield was consumed, each missed habit's row shows a shield icon instead of a flame.
- [ ] Only one shield is consumed per day regardless of how many habits were missed.
- [ ] Quit at end of a missed day with shields available; relaunch → yesterday auto-shielded, streak preserved.
- [ ] Back-fill an auto-shielded day to 100% completion → shield auto-returns to pool.
- [ ] Gray pending streak correctly counts shielded past days as successes (not misses).
- [ ] Schedule change that removes a shielded day from tracking does not reclaim the shield.
- [ ] Per-habit streaks compute correctly and are unaffected by shields.
- [ ] No regressions in Phases 1–7.

### Out of scope
- Earning shields by manual purchase or vacation conversion (Backlog).
- Multiple shields per day.
- Warning when removing a load-bearing shield.

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
- Replace Phase 6 local auth check with Supabase email/password auth. Reuse the existing `LoginView` and `CreateAccountView` screens — only the check logic swaps. Password reset and email verification added here.
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
