# Feature Spec — TerminalHabits

> What features exist and how they behave. This is the behavior contract; visual presentation lives in [design_spec.md](design_spec.md), interaction in [input_spec.md](input_spec.md), data shape in [data_model.md](data_model.md).

---

## 1. Feature inventory

| Feature | First phase | Notes |
|---|---|---|
| Splash + onboarding | Phase 0 | Decorative + first-run hook. |
| Daily view (checkbox habits) | Phase 1 | Core loop. |
| Habit creation (checkbox tracking) | Phase 1 | `NewHabitDialog` (create only; edit/archive moved to Phase 3). |
| Streaks for checkbox habits | Phase 1 | Pure-function recompute. |
| Habit groups | Phase 1 | Read-only in Phase 1; editable in Phase 7. |
| UI refinement (header, week strip intensity, sidebar pointer) | Phase 2 | Visual baseline. Sidebar retains nav; daily view gets terminal-output-style header; week strip cells get a per-day completion-intensity bar. |
| Group collapse + comment annotation | Phase 2 | `▼/▶` toggle persists; `groups.note` surfaces below header. |
| Inline streak / clock annotation on rows | Phase 2 | `🔥 N` and `🕒 HH:mm` from `habits.target_time`. |
| Habit editing (right-click / long-press) | Phase 3 | `EditHabitDialog` covers all fields. |
| Habit start date | Phase 3 | `habits.start_date` filters back-dated daily view. |
| Icon picker + group icons | Phase 4 | Curated `IconPickerDialog`; `groups.icon` adds icons to group headers. |
| Expanded color palette + tinted text | Phase 4 | 12 colors instead of 6; opt-in `colorIntensity` setting tints row text. |
| Inline note editing on rows | Phase 4 | Right-click → edit note. Mobile keeps dialog-based editing. |
| Schedule history / progress preservation | Phase 5 | `habit_schedule_history` + "keep progress?" prompt. |
| Tracking-type change with history | Phase 5 | Old completions remain valid under prior tracking. |
| Settings (theme, font, behavior) | Phase 6 | `SettingsDialog` + typed `settings` table; includes `warnFutureToggle`, `firstDayOfWeek`, `weekStartsAtMidnight`. |
| Stats view | Phase 7 | Overview, streaks, contributions, rates. |
| Vacation mode | Phase 7 | Pause streak decay during a date range. |
| Command palette (desktop) | Phase 7 | `Cmd+K` / `:` (basic palette stubbed in Phase 1). |
| Count tracking | Phase 7 | "did N times today." |
| Number tracking | Phase 7 | "logged N units" with unit string. |
| Health tracking | Phase 12 (Android only) | Auto-complete a habit on every app open / pull-to-refresh when today's Health Connect value ≥ daily goal. Steps shipped in the vertical slice; sleep / calories / water / exercise sessions to follow. Read-only access — the app never writes to Health Connect. |
| Mobile command grid | Phase 9 (shipped) | Touch replacement for command palette. |
| Tray icon | Phase 9 (Linux) | Show/hide window. |
| Cloud sync | Phase 10 / 11 (shipped) | Supabase auth, Realtime, and row-level LWW merge. |

---

## 2. Splash & onboarding (Phase 0)

### Splash

- Centered ASCII logo (stored as a single `String` with `\n` in `assets/ascii/logo.txt`, rendered via `SelectableText`).
- Below logo: `SystemInfoBox` showing version, platform, build mode (`release` / `debug`).
- Final line: `> press enter, or click anywhere — yours to shape.`
- Cursor blink: `AnimatedSwitcher` with 1 s opacity toggle on the trailing `_`.
- Click anywhere or press Enter → push `OnboardingView`.
- Persist `seenSplash = true` in `SharedPreferences`. On subsequent launches, skip splash unless launched with `--show-splash` debug flag.

### Onboarding (4 steps, custom Stepper)

1. **Name.** Single text field. Stored as `settings.userName`. Default: `you`.
2. **Theme pick.** Six theme cards (Matrix / Amber / IBM / Solar / Nord / Mono). Default: Matrix.
3. **First habits.** Pre-filled list of 5 example habits (read, walk, water, sleep early, 10 min stillness). User can toggle each on/off; toggled-on ones are inserted into the DB.
4. **Done.** Single button: `> begin`.

After step 4, push `DailyView`. Onboarding is one-shot — no return.

---

## 3. Daily view (Phase 1)

### Layout (top to bottom)

1. **Prompt line:** `${user}@TerminalHabits$ daily`
2. **Comment line:** `// no nudges. no streak panic.` (verbatim, do not change)
3. **Date row:** today's date in `YYYY-MM-DD ddd` format, e.g. `2026-05-07 thu`.
4. **Week strip:** seven `DayCell`s (Mon..Sun, this week). Each shows day-of-month, day-of-week initial, and a fill bar representing % habits done that day.
5. **Habit groups:** expandable sections. Each shows `[done/total]` in trailing.
6. **Habit rows:** see §3.2.

### Day boundary

A "day" is **local midnight to local midnight**, computed from `DateTime.now().toLocal()`. Stored in DB as the UTC timestamp of local midnight (truncated). The schedule and streak logic both honor this boundary.

DST: when the wall clock skips or repeats an hour, the local-midnight calculation absorbs it — no double counting.

### 3.2 Habit row

Anatomy (left-to-right, monospace, 14sp):

```
[ ] ●  read 30 min            /day · 12pp        🔥 14
└┬┘ │  └────┬─────┘            └───┬──┘           └┬┘
 │  │       │                      │              streak
 │  │       label                 meta (optional)
 │  icon (single character)
 checkbox (`[ ]` empty, `[✓]` done, `[~]` partial for counter/duration, `[!]` overdue today)
```

- **Tap** → toggle for checkbox; open value-input dialog for counter/duration; toggle (manual override) for health.
- **Long-press** → context menu: edit, archive, delete (with confirm).
- **Swipe-right** (mobile only) → quick-edit dialog.
- **Focused (desktop, j/k navigation)** → row gets `border` color `TH.line2`. `space` toggles.

### 3.3 Habit group

- `ExpansionTile` themed monospace.
- Default expanded. State persists per-group in `groups.collapsed`.
- Trailing chip: `[done/total]`. When `done == total`, the chip color shifts to `TH.green`.

### 3.4 Empty state

If no habits exist:

```
> no habits yet.
> press cmd+n to add one.
> or run :new
```

(Mobile: replace `cmd+n` with `tap +`, omit the `:new` line.)

---

## 4. Habit lifecycle

### 4.1 Create

Opened via `Cmd+N`, `:new`, or the `+` button (mobile).

**`NewHabitDialog` fields:**

| Field | Type | Required | Notes |
|---|---|---|---|
| Name | text | yes | 1–60 chars. |
| Group | dropdown / new | yes | Falls back to "general" if not set. |
| Icon | single char text | no | Defaults to `●`. Validated as 1 visible character. |
| Color | enum | no | one of {green, amber, blue, purple, teal, red}. Default green. |
| Tracking type | pill row | yes | `checkbox` / `counter` / `duration` / `health` (`health` Android only, Phase 12). |
| Target | int | conditional | required for counter (count), duration (minutes), and health (daily goal). |
| Unit | text | conditional | inferred from type: `min` for duration, `steps` for `health` + `steps` source. |
| Schedule | toggle group | yes | Daily (default), Weekdays, Weekends, Custom (7 day toggles). |
| Note | text (multiline) | no | Up to 280 chars. Shown in inspector when habit is focused. |

For `health` (Phase 12, Android only): an additional source picker is shown — initially just `steps` (other sources to follow). The daily goal field is required and used as the threshold for auto-completion. On Mac the `health` pill is hidden entirely. Permission to read the chosen Health Connect data type is requested when the habit is created; denial blocks the save with a "health connect denied" dialog.

### 4.2 Schedule semantics

- `daily` → due every day.
- `weekdays` → due Mon–Fri.
- `weekends` → due Sat–Sun.
- `custom` → due on the days listed in `schedule.days` (`[0..6]`, `0 = Mon`).

A habit not due on day D:
- Does not appear in DailyView for D.
- Does not break the streak if uncompleted.
- Counts as a "rest day" in stats.

### 4.3 Edit

Same dialog as create, prefilled. Changing tracking type is allowed but resets `target` and `unit`. Past completions are preserved as-is (not re-interpreted).

### 4.4 Archive vs delete

- **Archive** sets `archivedAt = now`. Habit hides from Daily but remains in Stats history.
- **Delete** is destructive: removes the habit and *all* its completions. Requires a confirm dialog with the literal text typed: `delete <habit name>`.

### 4.5 Reorder

Drag-and-drop within a group on desktop. On mobile, long-press → "move up / move down" in the context menu (no drag — too fiddly with one thumb). `sortIndex` is sparse-numbered (`100, 200, 300, ...`) so reorders rarely renumber.

---

## 5. Streaks & shields

Authoritative algorithm in [data_model.md](data_model.md) §6. Surface behavior:

### Per-habit streak (habit row + inspector)

- While today is still open (today is a due day and not yet completed): show **yesterday's streak in gray/dim** — never show 0 just because today isn't done yet. `todayAtRisk = true`.
- Once today's habit is completed (or today is not a due day): show the **current streak in amber**.
- After midnight if today was missed: current streak resets to 0 on the next wake.
- `StreakResult.displayStreak` returns `pending` when `todayAtRisk`, `current` otherwise.
- **Longest streak** displays in inspector and Stats Streaks block.

### Overall day-wise streak (daily view header)

- The header flame counts **consecutive days where every due habit was completed** (100% completion rate per day). Previously it showed `maxCurrentStreak` (the max streak across all habits); that is replaced.
- A day with no due habits is *neutral* — it neither contributes nor breaks the streak.
- Vacation days are neutral (skipped).
- Same pending/at-risk display logic as per-habit: gray when today is open and at least one due habit is incomplete, amber otherwise.

### Shields (Phase 8 placeholder)

`shields` in `StreakResult` is always 0. The shield system ships in Phase 8 with the following behavior (specified in [roadmap.md](roadmap.md) §Phase 8):
- One shield per day: if any habits were missed, one shield from the pool is consumed (not one per missed habit).
- Days with a consumed shield show a shield icon in the week strip instead of the flame.
- The shield counts as a successful day for streak purposes; the pending streak counts a shielded day as done.
- If a habit is later edited so that the shielded day is no longer tracked, the shield is kept (not reclaimed). No attempt to recover shields from schedule edits.

Vacation days are ignored entirely (neither break nor extend streaks).

---

## 6. Vacation mode

### Behavior
- One vacation row at a time can be active. Starting a new one while active replaces it.
- During an active vacation:
  - DailyView header replaces the prompt line with `${user}@TerminalHabits$ vacation [day N of M]`.
  - Habits still show but are dimmed; checking them is allowed and counts toward stats but not toward streaks.
  - Streak engine treats vacation days as neutral (skipped).
- Vacation can be **extended** (push end date) or **ended early** (clamp end to today).
- Past vacation ranges are stored and visible in the Vacation view as a list.

### View
- Centered ASCII palm tree from `assets/ascii/palm.txt`.
- Status: `on vacation. ${start} → ${end}. day N of M.`
- Two buttons: `[ extend ]` `[ end now ]`.
- Above buttons, a list of past vacations (date ranges only).

---

## 7. Stats view (Phase 7)

Five blocks, stacked. Each block is a `DecoratedBox` with a 1px border.

### 7.1 Overview
- Habits total (active / archived).
- Completions total (lifetime).
- Active streaks count (habits where `current > 0`).
- Compliance % (last 30 days, weighted by scheduled-due days).

### 7.2 Streaks
- Top 5 longest current streaks (habit name + length).
- Top 5 longest all-time streaks (habit name + length + when it ended, or "active").

### 7.3 Rates
- Per-habit completion rate over the last 30 days.
- Rendered as `BarRow`: label + striped track + filled portion + percentage.

### 7.4 Contributions
- 365-day grid (`ContributionGrid` widget).
- 7 rows × 53 columns approximately (last full year).
- Each cell colored by total completions that day, mapped to 5 levels via `Color.lerp(TH.bg3, TH.green, t)`.
- Hover (desktop) shows tooltip `${date}: ${count} completions`.
- Tap (mobile) shows the same in inspector drawer.

### 7.5 Day-of-week
- 7 `BarRow`s, one per weekday.
- Value = average completion rate that day-of-week over the last 90 days.

---

## 8. Settings dialog (Phase 7)

Two-pane modal. Left: section list. Right: section body.

### Sections

1. **General**
   - User name (text).
   - Default group for new habits (dropdown).
2. **Tweaks** (theme + font)
   - Theme: 6 cards (Matrix / Amber / IBM / Solar / Nord / Mono) with live preview swatches. Click to apply instantly.
   - Font size: 4 pills — `xs` (12sp body), `sm` (13sp), `md` (14sp, default), `lg` (15sp).
   - Font family: 8 preview cards. Each renders its own name in its own font. Default JetBrains Mono.
3. **Data**
   - Export to JSON (saves to `~/Documents/init-habits-export.json`).
   - Import from JSON (replaces current DB after confirm dialog).
   - DB location (read-only path).
4. **About**
   - Version, build number, Flutter version.
   - Link to repo (URL — opens via `url_launcher`).

Email + log-out controls live in the profile section since Phase 10 (Supabase auth). Password recovery via deep link added in Phase 12.

---

## 9. Command palette / mobile command grid

Full grammar, shortcut table, and grid layout in [input_spec.md](input_spec.md). This section just covers the *behavior contract*:

- The palette and grid both dispatch the same `Intent` types.
- Every command available in the palette must also be reachable via touch (and vice versa) — no orphan commands.
- Unknown commands show inline error `unknown: ${input}`. No autocorrect, no "did you mean."

---

## 10. Inspector pane (desktop)

Right pane, 280px wide. Content depends on the current view and selection.

| View / context | Inspector content |
|---|---|
| Daily, no habit focused | Today summary: due today / done today / streaks active. |
| Daily, habit focused | Habit detail: name, schedule, streak, longest, shields, last 14 days mini-grid, note. |
| Stats | Glossary block explaining each Stats block. |
| Vacation (active) | Days-into-vacation, days-remaining, "what counts toward streaks" reminder. |
| Settings open | Section help text. |

On mobile, this pane collapses to a bottom-sheet drawer triggered by a swipe-up from the status edge or a button in the bottom tab bar. See [design_spec.md](design_spec.md) §6.

---

## 11. Out of scope (v1)

- Notifications / reminders (D-006).
- iOS, Android tablets, Windows desktop.
- Habit dependencies ("read after walk").
- Quantitative goals beyond `target` (no streaks-by-quantity).
- Social features, sharing, leaderboards.
- Built-in journal / freeform notes per day.
- Real Apple Health on macOS (D-007).
- Plugin system / extensibility.
