# Roadmap — TerminalHabits

> Phased delivery plan. Each phase ships a runnable, dogfoodable build before the next begins. Phase order is fixed: macOS → Android. Cloud sync is a deferred post-1.0 phase.

---

## Phase 0 — Bootstrap (≈ 1 week)

**Completed: 2026-05-07**

**Goal:** an empty-but-themed Flutter desktop app that boots on macOS into the splash screen and accepts no input besides "click to onboard."

### Scope
- Initialize Flutter project: `flutter create --platforms=macos,android terminal_habits`.
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
- Android build, any habit features.

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
- Full touch-friendly counter/duration input (Phase 9).

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

**Completed: 2026-05-10**

**Goal:** multi-user local auth with full per-user data isolation. Habits, groups, and vacations are scoped to the logged-in user. Login and registration are required on every fresh launch.

### Scope

#### Users table & data isolation
- **New `users` table**: `id INTEGER PK autoincrement`, `username TEXT UNIQUE`, `display_name TEXT`, `password TEXT` (plaintext — Phase 10 replaces with hashed + Supabase), `created_at DATETIME`.
- **`user_id` column** added to `habits`, `groups`, and `vacations`. All read/write queries filter by the logged-in user's id. Completions and `habit_schedule_history` are implicitly isolated through their `habit_id` FK.
- **Migration v6**: create `users` table; add `user_id INTEGER NOT NULL DEFAULT 1` to habits/groups/vacations; seed a placeholder user `(id=1, username='dev', password='dev', display_name=existing userName setting)` so existing data is assigned to user 1 and remains accessible.
- Fresh install: no placeholder user; registration creates the first user and the default 'general' group.

#### Auth flow
- **`RegisterView`**: fields — display name, username, password, confirm password. No validation rules in this phase (any length, any characters). On submit: insert user row, create default 'general' group for that user, set `SharedPreferences.loggedInUserId`, update `currentUserIdProvider`, push `OnboardingView`.
- **`LoginView`**: fields — username, password. On match: set SharedPreferences + provider, push `AppScaffold`. On mismatch: inline red error, no lockout. Two footer links: `[ register ]` → `RegisterView`, `[ forgot password ]` → `ForgotPasswordView`.
- **`ForgotPasswordView`**: enter username → if found, display the plaintext password from the DB directly on screen. Prominent note: "this is a temporary local dev feature — Phase 10 will replace it with email recovery." Link back to `[ login ]`.
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
- [x] Fresh install: splash → register → onboarding → daily view.
- [x] Subsequent launch: splash → login → daily view. Wrong password shows inline red error.
- [x] `[ forgot password ]`: enter username → plaintext password shown on screen.
- [x] Habits, groups, and vacations created by user A are invisible when logged in as user B.
- [x] User button in sidebar shows initial + display name; tapping opens `UserWindow`.
- [x] `UserWindow` shows username, member since, total completions, current streak; display name editable.
- [x] Log out → next launch shows `LoginView`.
- [x] Existing pre-auth data (migration) assigned to dev/dev user and still visible after login.

### Out of scope
- Password hashing, email, OAuth — Phase 10.
- Settings dialog, archive in settings — Phase 6b.
- Stats view, vacation mode — Phase 7.

---

## Phase 6b — Settings dialog & archive relocation (≈ 1 week)

**Completed: 2026-05-10**

**Goal:** a real settings surface; archive moved out of sidebar nav into settings; `Cmd+,` shortcut wired.

### Scope
- **`SettingsDialog`**: opened via `Cmd+,`, command palette `settings`, or the `[ ⚙ settings ]` button in `UserWindow` (replaces the Phase 6a stub).
  - **Appearance**: font size pills (sm/md/lg — instant apply via `textScaler`), theme switcher (6 swatches — instant apply via `AppColors extends ThemeExtension<AppColors>`; all widget color tokens refactored from static `TH` constants to `context.col` lookups).
  - **Behavior**: `allowFutureMarking` (bool, default `false`), `confirmDestructive` (bool, default `true`).
  - **Data**: archived habits list with restore / delete actions inline.
  - **About**: version, storage note, plaintext-password disclaimer.
- **Individual setting `StreamProvider`s** (`fontSizeProvider`, `allowFutureMarkingProvider`, `confirmDestructiveProvider`, `themeIdProvider`) backed by `watchSetting` on the Drift `AppSettings` table.
- **Font size** applies instantly app-wide via `MediaQuery.textScaler` override in `App`.
- **`Cmd+,`** wired in `AppScaffold` shortcuts (macOS).
- **`OpenSettingsIntent`** already existed in `intents.dart`; now wired in `AppScaffold`.
- **`allowFutureMarking`** checked at both toggle call sites (`app_scaffold._toggleFocused`, `habit_row._handleTap`) before calling `confirmFutureToggle`.
- **Archive**: inline archive list in Settings → Data section. Sidebar nav has no archive entry.
- **Command palette**: `settings` command added; stale `profile` command removed.

### Schema changes
- No new tables. New keys seeded in `_seedDefaults`: `allowFutureMarking = 'false'`, `confirmDestructive = 'true'`.

### Exit criteria
- [x] `SettingsDialog` opens via `Cmd+,`, command palette, and user window settings button.
- [x] Font size updates instantly across all visible widgets (sm/md/lg scale).
- [x] Theme color updates instantly — implemented via `AppColors extends ThemeExtension<AppColors>`; all 33 widget files refactored from static `TH.colorXxx` to `context.col.xxx`.
- [x] `allowFutureMarking = true` skips the future-day warning dialog.
- [x] Archived habits listed under Settings → Data with restore and delete actions.
- [x] All behavior settings persist across restart.

### Out of scope
- Per-user settings scoping (settings remain global in this phase).
- Stats, command palette polish, vacation — Phase 7.

---

## Phase 7 — macOS Polish: stats, command palette, vacation, tracking types (≈ 2.5 weeks)

**Started:** 2026-05-10  
**Completed:** 2026-05-14

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
- [x] Command palette opens in <50 ms, filters live, Enter dispatches.
- [x] All keyboard shortcuts in `input_spec.md` table work.
- [x] Stats view contributions grid renders 365 days correctly across DST boundaries and across schedule-history changes.
- [x] Vacation mode pauses streak decay (verified by test).
- [x] No regressions from Phases 1–5.

### Out of scope
- Android build, sync.

---

## Phase 8 — Per-day shield system (≈ 1.5 weeks)

**Completed:** 2026-05-17

**Goal:** add a shield pool that absorbs missed days in the overall day-wise streak at the moment they occur. One shield covers one missed day. Shields earned later never reach back to fix already-broken streaks.

### Design principles

#### Shield application is forward-only
A shield is consumed at the transition moment — when a day rolls from "today" to "yesterday", detected at the next app launch. If no shield was available at that transition, the day is permanently locked as a miss. Earning shields later does **not** retroactively heal past missed days. This keeps the streak history trustworthy: what you see is what actually happened, shielded or not.

#### `last_seen_date` tracks the transition boundary
A `last_seen_date` value (stored in `settings`) records the last calendar date on which the launch scan ran. On each launch:
1. Compute the gap from `last_seen_date + 1` to yesterday (inclusive), in chronological order.
2. For each day in the gap: if it was a missed day and `available_shields > 0`, consume one shield and insert a `day_shields` row. Otherwise leave it as a miss.
3. Update `last_seen_date` to today.

Days already processed (before `last_seen_date`) are never re-evaluated, even if shields are earned later.

#### Long-term storage safety
All IDs use SQLite's 64-bit `INTEGER AUTOINCREMENT` — no overflow for any realistic usage horizon. Dates are stored as 64-bit epoch milliseconds (Drift's default `DateTime` mapping) — safe past year 292 million. Dart's native `int` is 64-bit. Streak and completion counts are plain Dart `int` (64-bit). No 32-bit integers are used anywhere in the data or domain layer.

#### Local-first and sync resilience
The local SQLite file is always the source of truth. All primary keys are assigned locally (no server-generated IDs), so a full re-push of every row to a clean remote (Supabase or otherwise) is always possible without key collisions. If a remote loses data, the local DB is the recovery source. This guarantee must be preserved in Phase 10 (sync).

---

### Scope

- **New table** `day_shields(id INTEGER PK AUTOINCREMENT, day DATETIME UNIQUE, applied_at DATETIME)`.
  - `day` is UTC-midnight-of-local-day (same convention as `completions.day`).
  - `UNIQUE` on `day` — at most one shield per calendar day, ever.
  - No `source` column: all shields in this phase are auto-applied; manual apply is out of scope.
- **One shield per day**: if any habits were incomplete on a given day, one shield is consumed from the pool — not one per missed habit. Vacation days do not consume shields (already successful by definition).
- **Day-success definition**: a day is *successful* when all due habits are completed OR a row in `day_shields` exists for that day.
- **Overall streak engine**: `computeOverallStreak` walker treats a shielded day as outcome `1` (success).
- **Per-habit streaks**: unchanged — shields have no effect on individual habit streaks.
- **Shield earning**: every N consecutive successful days (shielded days count) earns 1 shield. `N` defaults to 7, stored as `shieldEarnInterval` in settings. The available pool is a single integer counter `available_shields` in settings.
- **Launch scan** (`last_seen_date` logic above): processes missed days chronologically, consuming shields where available, then locks. Updates `last_seen_date` to today.
- **Auto-recovery**: if a shielded day is back-filled to 100% completion, the `day_shields` row is deleted and `available_shields` is incremented by 1. Triggered on any completion write.
- **Shield permanence on schedule edits**: if a habit's schedule is retroactively changed so a previously shielded day is no longer tracked, the shield row is kept (not reclaimed).
- **UI — habit row**: on a shielded day where a specific habit was *not* completed, show a shield icon (🛡) instead of the flame. Multiple habits missed on the same shielded day all show the shield icon; only one shield was consumed.
- **UI — pending streak**: the gray pending streak counts shielded past days as successful days (not misses).
- **UI — header**: `🛡 {available}` shows the current pool count next to the streak.
- **UI — week strip**: `🛡` overlay on day cells where a shield was consumed.
- **Stats — shielded days metric**: new counter in the Overview block showing total shielded days in the tracked window. Shielded days count as successful in all existing metrics (perfect days, streak length) but are also surfaced separately so the user can see how many times shields have been used.
- **Migration cleanup**: `StreakResult.shields` field removed (currently always 0); `DailyState.availableShields` backed by the real `available_shields` settings value.

### Schema changes
- DB migration (new version): `CREATE TABLE day_shields`. Add `available_shields` setting (default `'0'`). Add `shieldEarnInterval` setting (default `'7'`). Add `last_seen_date` setting (default `''` — empty string triggers a first-run scan from the earliest habit start date or 90 days back, whichever is later).

### Exit criteria
- [x] Quit at the end of a missed day with shields available; relaunch → that day auto-shielded, streak preserved.
- [x] Same scenario with no shields available → day stays as a miss, streak broken, earning shields later does not fix it.
- [x] On a shielded day where habits were missed, each missed habit's row shows a shield icon instead of a flame.
- [x] Only one shield consumed per day regardless of how many habits were missed.
- [x] Back-fill a shielded day to 100% completion → shield auto-returns to pool.
- [x] Gray pending streak counts shielded past days as successes.
- [x] Schedule change that removes a shielded day from tracking does not reclaim the shield.
- [x] Stats overview shows correct "shielded days" count; shielded days still count toward perfect days and streak length.
- [x] Per-habit streaks unaffected by shields.
- [x] No regressions in Phases 1–7.

### Out of scope
- Manual apply / remove shield from UI.
- Applying shields to specific future days.
- Earning shields by manual purchase or vacation conversion (Backlog).
- Multiple shields per day.

---

## Phase 9 — Android adaptation (≈ 4 weeks)

**Completed: 2026-05-19**

**Goal:** a `.apk` that delivers the same habit-tracking experience via touch, with the same visual aesthetic.

This phase is the largest UX shift. See [input_spec.md](input_spec.md) §3 for the full mobile interaction model and [design_spec.md](design_spec.md) §6 for the layout breakpoint behavior.

### Scope
- Single-pane layout under `LayoutBuilder` breakpoint `<720px`:
  - Top tab bar (Daily / Stats / Profile, 3 tabs) styled like terminal tabs — replaces the desktop sidebar on phones; tablets in landscape may keep the sidebar.
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
- [x] `.apk` installs and runs on Android 7.0 (minSdk 21) and Android 14.
- [x] Same feature set as Phases 5 + 6 works via touch only — no keyboard plugged in.
- [x] No regressions on macOS from the touch refactor.
- [ ] One full week of dogfooding on a personal Android device with no critical bugs. *(ongoing)*
- [ ] Health Connect wires `[health]` habits to step count. *(deferred post-1.0)*

**Soft target:** `.apk` size under 30 MB (not a blocking criterion).

### Out of scope
- iOS, Android tablets (deferred).
- Widgets, complications.
- Background sync, foreground services.

---

## Phase 10 — Cloud sync / Supabase auth

**Completed: 2026-05-20**

**Goal:** opt-in multi-device sync. User signs in once on each device; habits and completions converge.

### What shipped
- Supabase email/password auth replacing local plaintext auth. `LoginView`, `RegisterView`, `ForgotPasswordView` all rewritten to use Supabase SDK.
- `SyncService` with `pushAll()` / `pullAll()` — full replace-all sync using local SQLite as source of truth.
- Auto-push: debounced 2s push fires after any local write (Drift stream listeners in `AppScaffold`).
- Manual sync: `Cmd+R` shortcut and `[ sync with cloud ]` command palette entry trigger push-then-pull.
- Pull-to-refresh on Android triggers `pullAll()`.
- Login flow: `pullAll()` on sign-in; if server empty, `pushAll()` seeds it from local. Post-pull habit check skips onboarding if habits already exist (second-device login).
- Onboarding pushes starter habits to Supabase after creation.
- macOS sandbox `com.apple.security.network.client` entitlement added.
- macOS key-repeat Flutter assertion (`physical key already pressed`) intercepted and cleared via `HardwareKeyboard.instance.clearState()`.
- `RefreshIndicator` always wraps body on Android (including empty/vacation states) with `AlwaysScrollableScrollPhysics`.
- Push is FK-safe: deletes in child-first order (completions → shields → history → habits → groups → vacations), reinserts in parent-first order.
- `pullAll()` guarded: skips if server has no habits (protects against mid-push race condition from another device). `SyncService.isPulling` flag with 3s cooldown suppresses auto-push after a pull.

### Exit criteria
- [x] Two devices stay in sync within ~2s of online activity (auto-push debounce).
- [x] Going offline doesn't block any local action.
- [x] Sign-out leaves the device fully usable.
- [ ] Atomic multi-table fetch (race condition between concurrent device pushes) — deferred to Phase 11 (Supabase Realtime).

### Known limitations (Phase 11)
- Sync is full replace-all, not row-level merge. Concurrent pushes from two devices can race; protected by the `serverHabits.isEmpty` guard but not fully solved.
- No Supabase Realtime — second device must manually pull (Android: pull-to-refresh; Mac: Cmd+R).
- Deleting all habits on one device won't propagate to other devices (guard prevents it).

---

## Phase 11 — Sync v2: Realtime + row-level merge (≈ 2 weeks)

**Completed: 2026-05-21**

**Goal:** make multi-device sync reliable. Replace the delete-all-reinsert push model with a proper diff-based approach and add Supabase Realtime so the second device updates automatically without manual pull.

### Scope

- **Row-level upsert merge**: remove the bulk `DELETE … WHERE user_id` from `pushAll()`. Instead, upsert only rows that exist locally and delete only rows that are missing locally (by diffing local IDs vs server IDs per table). This eliminates the window between delete and reinsert that currently causes data loss on concurrent pushes.
- **Tombstone pattern for deletions**: add a `deleted_at TIMESTAMPTZ` column to `habits`, `groups`, `vacations`, `completions`. Local deletes set `deleted_at` rather than removing the row. `pushAll()` upserts tombstoned rows; `pullAll()` removes local rows whose server counterpart is tombstoned. Drift schema migration required.
- **Supabase Realtime subscriptions**: subscribe to `INSERT`/`UPDATE`/`DELETE` events on `habits`, `completions`, `groups` via `supabase.from(...).stream(...)` or `RealtimeChannel`. On receiving a change, apply it locally as a targeted upsert/delete rather than a full pull. This replaces manual Cmd+R / pull-to-refresh for the second device.
- **Remove `SyncService.isPulling` guard and `serverHabits.isEmpty` guard** once the race condition is structurally eliminated.
- **Remove `pushAll()` from login** — with Realtime active, login just needs to pull current state once.

### Exit criteria
- [x] Edit a habit on Mac; it appears on Android within 3 seconds with no manual action.
- [x] Delete a habit on one device; it disappears on the other within 3 seconds.
- [x] Two devices editing different habits simultaneously converges correctly (LWW via `updated_at`).
- [x] App works fully offline; changes push automatically when connectivity resumes.

### Out of scope
- Conflict resolution for the same habit edited on two devices simultaneously (last-write-wins per field is acceptable for now).
- iOS.

---

## Phase 12 — Android polish + Health Connect (≈ 2.5 weeks)

**Completed: 2026-05-23**

**Goal:** complete the Android habit experience with group management, Health Connect auto-tracking, and remaining UX polish.

### Scope

**Group management**
- **Editable groups**: long-press / right-click a group header opens a menu with `rename`, `edit icon`, `edit note`, and `delete`. Clearing the rename field to empty triggers the delete flow.
- **Group deletion**: `general` is the default group and cannot be deleted or renamed. For other groups, the delete dialog asks how to handle their habits: reassign to another group, or cascade soft-delete the habits along with the group. Default selection is reassign to the first non-deleted group (typically `general`).
- Sync: group edits stamp `updatedAt` and propagate via LWW diff-push/Realtime. Tombstones (`deleted=true`) persist locally so removals propagate to other devices.

**Android UX fixes**
- **Archive snackbar position**: the undo snackbar currently appears below the FAB and is obscured by the bottom nav bar. Move it above the FAB so it is always visible.
- **Haptic feedback audit**: swipe and long-press are already implemented. Verify and fill in the full desired matrix: light tap on completion toggle, medium on archive/delete confirm, error pattern on destructive actions. Fix any missing sites.
- **Android app icon**: design and wire launcher icon (adaptive icon with foreground/background layers).

**Display name change**
- Allow the user to update their display name (the name shown in the profile header and the daily view prompt line) from the profile screen.
- UI: an edit button or tap-to-edit inline field in `UserWindow` for the name row. Saves to both the local `users` table and Supabase user metadata (`data['display_name']`) so it persists across devices.
- No password confirmation required — display name is non-sensitive.

**Password recovery (deep-link, app-required)**
- Password recovery requires the app to be installed on the device where the recovery email link is clicked. This is an accepted limitation — no web fallback.
- Register custom URL scheme `terminalhabits://` in `macos/Runner/Info.plist` and Android intent filters in `AndroidManifest.xml` (scheme + host), so the link opens from any email client or browser on the device.
- Add `app_links` package to receive the incoming URL at the Flutter layer.
- Add the scheme (`terminalhabits://`) to Supabase dashboard → Auth → URL Configuration as an allowed redirect URL. Supabase will redirect to `terminalhabits://login-callback#access_token=…&type=recovery` after verifying the OTP.
- On receiving the deep link: parse `access_token` + `refresh_token` from the URL fragment, call `supabase.auth.setSession(accessToken, refreshToken)`, then navigate to `ResetPasswordView`.
- `ResetPasswordView`: new password + confirm fields. The old password remains valid and usable for login until the user explicitly submits. On submit: call `supabase.auth.updateUser(UserAttributes(password: newPassword))`, then `supabase.auth.signOut(scope: SignOutScope.global)` to invalidate all sessions on all devices, then navigate to `LoginView`.
- All other devices detect session invalidation via `supabase.auth.onAuthStateChange` (fires `signedOut`) and redirect to `LoginView` automatically.

**Health Connect auto-tracking** *(primary focus)*
- When creating or editing a habit, `tracking = 'health'` unlocks a **health source** selector.
- Supported sources (initial set): steps, water (glasses), active calories, exercise sessions (walking, running, biking, etc.), sleep duration. Backed by the `health` package (already in pubspec).
- User sets a **daily numeric goal** (e.g. 8000 steps, 8 glasses, 30 min biking).
- On every app open (and on pull-to-refresh), the app reads today's value from Health Connect and compares it to the goal. If the value meets or exceeds the goal, the habit is automatically marked complete for today. If the value drops below the goal (e.g. midnight rollover), the completion is soft-deleted.
- Requires `health_connect` permission request on first use of a health-backed habit. Read-only scope; no writes to Health Connect.
- No separate health dashboard — native apps (Samsung Health, Google Fit, etc.) handle that. This is purely a goal-gate that feeds the habit tracker.
- `healthSource` column already exists on `Habits` table. Store the chosen metric key there (e.g. `'steps'`, `'water_glasses'`, `'biking_minutes'`). `target` column stores the daily goal value.

### Exit criteria
- [x] Group name and icon are editable from the long-press menu; changes sync to the other device.
- [x] Deleting a non-general group prompts for reassign-or-cascade; either option syncs to the other device.
- [x] `general` group cannot be deleted or renamed.
- [x] Archive undo snackbar appears above the FAB on Android.
- [x] Haptic feedback fires on archive + delete on Android (reduced from the original "toggle / archive / destructive confirm" scope at user request).
- [x] Android app icon visible on home screen.
- [x] Display name is editable from the settings screen; change persists across devices via Supabase metadata.
- [x] Clicking the recovery email link on a device with the app installed opens `ResetPasswordView` directly (works from email clients and browsers on Android and macOS).
- [x] Old password remains valid for login until the user submits a new one.
- [x] Submitting a new password logs out all other active sessions; current device navigates to `LoginView`.
- [x] Other logged-in devices are automatically redirected to `LoginView` when their session is invalidated (on next cold launch via `refreshSession` revocation check).
- [x] Creating a habit with `tracking = health` → steps source → goal: habit auto-completes when Health Connect reports value ≥ goal for today.
- [x] Health Connect permission prompt appears on first health-backed habit save.
- [x] Health read runs on every app open and on pull-to-refresh; no manual action required.
- [x] Sleep and exercise sources also supported (steps + sleep + exercise; water and calories declined).

### Out of scope
- Health dashboard or health data visualisation (use native health apps).
- Inspector bottom sheet on Android (removed; not planned).
- App distribution / Play Store / notarization (personal use only; release artifacts published as GitHub releases if needed).
- iOS.

---

## Phase 13 — Backup, polish, and Phase 12 follow-ups

**Not started**

**Goal:** four self-iteration items — a few targeted fixes from Phase 12 (sleep input ergonomics, server-side dedupe, launch-scan visibility) plus local JSON backup/restore. Personal-use scope; no features added for hypothetical other users.

### Scope

- **Bulk import/export (`.json`)**: export all habits + completions + groups + vacations + shields + schedule history to a structured JSON file (versioned by `schemaVersion`). Import wipes local data and replaces from the file. Triggered from Settings → Data. Acts as a manual backup mechanism that complements Supabase sync.
- **Server-side completion dedupe** (one-off SQL): clean up duplicate `(user_id, habit_id, day)` rows on Supabase. Different devices' autoincrement IDs caused dup rows during Phase 12 testing; the client now handles them, but the server should also be cleaned up.
- **`ValueInputDialog` hours mode for sleep**: when manually overriding a sleep habit's value, accept hours instead of minutes. Internal storage stays in minutes; the dialog converts on display and on save. Matches the goal-entry behavior already in the new/edit habit dialogs.
- **Launch-scan summary toast**: after the launch shield scan runs (which walks `last_seen_date + 1` through yesterday), surface a toast if any days were missed or shielded. E.g. "2 days shielded, 1 day missed" if the user was away for a few days. Suppressed when the scan range is empty (user opened the app yesterday too).

### Exit criteria
- [ ] Settings → Data → Export produces a valid JSON file containing the full local DB state, restorable via Import on the same or another device.
- [ ] Import refuses files whose `schemaVersion` doesn't match the current DB schema.
- [ ] Phase 13 phase log includes the one-off SQL the user ran in Supabase to dedupe completions (with the date it was run).
- [ ] Tapping a sleep habit on the daily view opens the value-input dialog showing hours (e.g. `7`), not minutes (`420`).
- [ ] After a multi-day absence, the next app open shows a one-time toast summarizing what was shielded vs missed during the gap.

### Out of scope
- macOS resizable splits, manual shield apply/remove, global hotkey, habit templates, per-habit reminders, Health Connect water/calories, stats charts for health habits — all explicitly deferred per personal-iteration scope.
- iOS, CI/CD.

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
- iOS App Store submission.
- Android tablets.
- CI/CD pipeline (GitHub Actions: analyze + test on PR, build artifacts on tag).
- Windows desktop (D-002).
