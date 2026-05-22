# Data Model — TerminalHabits

> Drift schema, indexes, migrations, and the streak algorithm. This is the contract every persistence and computation layer adheres to. Behavior in [feature_spec.md](feature_spec.md) is implemented against this shape.

---

## 1. Tables (drift)

```dart
// Users — local row for the logged-in Supabase user (id=1 always).
class Users extends Table {
  IntColumn      get id          => integer().autoIncrement()();
  TextColumn     get username    => text().unique()();    // = Supabase email
  TextColumn     get displayName => text()();
  // Legacy plaintext column kept for the Drift schema; Supabase auth replaced
  // local passwords in Phase 10 so this field is never read for auth now.
  TextColumn     get password    => text()();
  DateTimeColumn get createdAt   => dateTime().withDefault(currentDateAndTime)();
}

// Groups
class Groups extends Table {
  TextColumn     get id        => text().clientDefault(_uuid)();
  IntColumn      get userId    => integer().withDefault(const Constant(1))();
  TextColumn     get name      => text()();
  IntColumn      get sortIndex => integer()();
  BoolColumn     get collapsed => boolean().withDefault(const Constant(false))();
  TextColumn     get note      => text().nullable()();
  TextColumn     get icon      => text().nullable()();
  // LWW sync columns (Phase 12).
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn     get deleted   => boolean().withDefault(const Constant(false))();

  @override Set<Column> get primaryKey => {id};
}

// Habits
class Habits extends Table {
  IntColumn      get id         => integer().autoIncrement()();
  IntColumn      get userId     => integer().withDefault(const Constant(1))();
  TextColumn     get groupId    => text().references(Groups, #id)();
  TextColumn     get name       => text()();
  TextColumn     get icon       => text().withDefault(const Constant('●'))();
  TextColumn     get color      => text().withDefault(const Constant('green'))();
  TextColumn     get tracking   => text()();   // 'checkbox' | 'counter' | 'duration' | 'health'
  IntColumn      get target     => integer().nullable()();    // for counter/duration/health
  TextColumn     get unit       => text().nullable()();       // e.g. 'min', 'steps'
  TextColumn     get schedule   => text()();   // JSON: {"days":[0..6]}
  TextColumn     get note       => text().nullable()();
  TextColumn     get targetTime => text().nullable()();       // "HH:mm" 24h
  IntColumn      get sortIndex  => integer()();
  TextColumn     get healthSource => text().nullable()();     // 'steps', etc. (Phase 12)
  DateTimeColumn get createdAt    => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get startDate    => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get endDate      => dateTime().nullable()();
  DateTimeColumn get archivedAt   => dateTime().nullable()();
  // LWW sync + soft-delete tombstone (Phase 11).
  DateTimeColumn get updatedAt    => dateTime().withDefault(currentDateAndTime)();
  BoolColumn     get deleted      => boolean().withDefault(const Constant(false))();
}

// Completions — one row per (habit, day). Soft-delete via `deleted=true`
// when unchecked, so deletions propagate via sync.
class Completions extends Table {
  IntColumn      get id        => integer().autoIncrement()();
  IntColumn      get habitId   => integer().references(Habits, #id)();
  DateTimeColumn get day       => dateTime()();
  RealColumn     get value     => real().withDefault(const Constant(1.0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  // LWW sync + soft-delete tombstone (Phase 11).
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn     get deleted   => boolean().withDefault(const Constant(false))();

  @override List<Set<Column>> get uniqueKeys => [{habitId, day}];
}

// HabitScheduleHistory — append-only log of (schedule, tracking) changes.
// Each habit's effective schedule for a given day is the most recent row
// with effective_from <= day. Backfilled at habit creation.
class HabitScheduleHistory extends Table {
  IntColumn      get id            => integer().autoIncrement()();
  IntColumn      get habitId       => integer().references(Habits, #id)();
  DateTimeColumn get effectiveFrom => dateTime()();   // UTC midnight of local day
  TextColumn     get schedule      => text()();
  TextColumn     get tracking      => text()();
  DateTimeColumn get createdAt     => dateTime().withDefault(currentDateAndTime)();
}

// Vacations — one active at a time, plus history.
class Vacations extends Table {
  IntColumn      get id      => integer().autoIncrement()();
  IntColumn      get userId  => integer().withDefault(const Constant(1))();
  DateTimeColumn get start   => dateTime()();
  DateTimeColumn get end     => dateTime()();
  TextColumn     get note    => text().nullable()();
  BoolColumn     get active  => boolean().withDefault(const Constant(false))();
}

// DayShields — one row per calendar day where the overall streak was
// preserved by consuming a shield instead of recording a miss.
class DayShields extends Table {
  IntColumn      get id        => integer().autoIncrement()();
  DateTimeColumn get day       => dateTime()();   // UTC midnight of local day
  DateTimeColumn get appliedAt => dateTime().withDefault(currentDateAndTime)();

  @override List<Set<Column>> get uniqueKeys => [{day}];
}

// AppSettings — key/value sidecar. Device-local (not synced).
class AppSettings extends Table {
  TextColumn get key   => text()();
  TextColumn get value => text()();

  @override Set<Column> get primaryKey => {key};
}
```

### Settings keys (canonical, in `app_settings`)

| Key | Value type | Default |
|---|---|---|
| `userName` | string | `"you"` (legacy; profile name now comes from `users.display_name`) |
| `themeId` | enum (matrix / hacker / nord / solarized / monokai / gruvbox) | `"matrix"` |
| `fontSize` | enum sm/md/lg | `"md"` |
| `fontFamily` | string | `"JetBrains Mono"` |
| `lastView` | enum daily/stats/profile | `"daily"` |
| `allowFutureMarking` | bool string | `"false"` |
| `confirmDestructive` | bool string | `"true"` |
| `available_shields` | int string | `"0"` |
| `shieldEarnInterval` | int string | `"7"` |
| `last_seen_date` | ISO date string `"YYYY-MM-DD"` | `""` (triggers first-run scan) |

`shared_preferences` is used for cross-launch flags that must be readable before the DB opens or that are intentionally non-synced: `seenSplash`, `seenOnboarding`, `last_auth_uid`. Everything else lives in `app_settings`.

`app_settings` is **device-local** — it is not pushed to Supabase. Each device computes its own shield pool / theme / font scale.

---

## 2. Long-term durability guarantees

This app is designed for multi-year continuous use. The following constraints are enforced throughout the data and domain layers:

| Concern | Guarantee |
|---|---|
| Row IDs | All `autoIncrement()` columns use SQLite's 64-bit INTEGER. At 1 million completions/year, overflow occurs in ~9 trillion years. |
| Timestamps | Drift stores `DateTime` as 64-bit epoch milliseconds. Safe past year 292 million. |
| Streak / completion counts | Dart native `int` is 64-bit on all target platforms (macOS, Android). No 32-bit cast anywhere in the domain layer. |
| Shield pool counter | Plain integer in `settings`. Capped at `999` in the UI to prevent display overflow; no arithmetic overflow risk. |
| Timezone shifts | All day values are UTC midnight of local day at write time. A timezone change does not corrupt existing rows; it only shifts the boundary of "today." |
| DST transitions | Days computed with `DateTime(y, m, d).toUtc()`, never as `epoch / 86400`. |

**Local-first sync resilience:** The local SQLite file is always the source of truth. All primary keys are assigned locally (no server-generated IDs). A complete re-push of every local row to a clean remote is always possible without key collisions. If a remote loses data, the local DB is the full recovery source. This guarantee must be preserved in Phase 10 (sync): the sync layer must support a full local → remote push on demand.

---

## 3. Indexes

```dart
// In drift @DriftDatabase migration:
await m.createIndex(Index('idx_completions_day', 'CREATE INDEX idx_completions_day ON completions(day)'));
await m.createIndex(Index('idx_completions_habit_day', 'CREATE INDEX idx_completions_habit_day ON completions(habit_id, day)'));
await m.createIndex(Index('idx_habits_group_sort', 'CREATE INDEX idx_habits_group_sort ON habits(group_id, sort_index)'));
await m.createIndex(Index('idx_habits_archived', 'CREATE INDEX idx_habits_archived ON habits(archived_at)'));
await m.createIndex(Index('idx_day_shields_day', 'CREATE INDEX idx_day_shields_day ON day_shields(day)'));
```

Stats queries scan completions by date range; the `(habit_id, day)` composite handles streak recomputation efficiently.

---

## 4. Day boundary & timezone handling

- Every `Completion.day` is the UTC instant of **local midnight on the day the user checked the habit.**
- Computation: `final day = DateTime(now.year, now.month, now.day).toUtc();`
- This means moving to a new timezone shifts which "day" yesterday's completion belongs to. That's intentional and matches user intuition: a 11pm completion in NYC stays "yesterday" if you fly to LA overnight.
- DST transitions: the DateTime constructor handles the skipped/repeated hour correctly; we never compute days as `epoch_seconds / 86400`.
- All comparisons in queries use `>= start_of_day_utc AND < start_of_next_day_utc` (no `BETWEEN`).

---

## 5. Schedule encoding

`habits.schedule` is JSON:

```json
{ "days": [0, 1, 2, 3, 4] }   // weekdays
```

- `days` is always an explicit list of weekday integers (`0 = Mon, 6 = Sun`).
- `daily` → `[0,1,2,3,4,5,6]`. We do not store a separate `kind` field; the list is canonical.
- `weekends` → `[5,6]`.
- `custom` → whatever the user picked, in sorted order.

The schedule resolver (`domain/schedule.dart`):

```dart
bool isHabitDueOn(Habit h, DateTime localDay) {
  final weekday = (localDay.weekday + 6) % 7;   // Dart: 1=Mon..7=Sun → 0=Mon..6=Sun
  final days = (jsonDecode(h.schedule)['days'] as List).cast<int>();
  return days.contains(weekday);
}
```

---

## 6. Migrations

drift's `MigrationStrategy`. Every schema bump increments `schemaVersion`.

```dart
@override
MigrationStrategy get migration => MigrationStrategy(
  onCreate: (m) async { await m.createAll(); /* + indexes from §2 */ },
  onUpgrade: (m, from, to) async {
    if (from < 2) { /* migration v1 → v2 */ }
    if (from < 3) { /* migration v2 → v3 */ }
  },
);
```

Migrations are append-only. Never edit a past migration once shipped — write a new one. Phase 1 ships with `schemaVersion = 1`.

### Planned migrations (per [roadmap.md](roadmap.md))

These are committed in scope; column-level details get fleshed out here in the PR that introduces each phase.

| Version | Phase | Adds |
|---|---|---|
| v2 | Phase 2 | `groups.note TEXT NULL`; `habits.target_time TEXT NULL` (HH:mm 24h). |
| v3 | Phase 3 | `habits.start_date DATETIME NOT NULL` (backfilled from `created_at`). |
| v4 | Phase 4 | `groups.icon TEXT NULL` (backfilled `'▸'`). |
| v5 | Phase 5 | `habit_schedule_history(id, habit_id, effective_from, schedule, tracking, created_at)` with `(habit_id, effective_from DESC)` index. `habits.end_date DATETIME NULL`. Backfills one history row per habit. |
| v6 | Phase 6a | `users(id, username, display_name, password, created_at)` (plaintext password until Phase 10 replaced this with Supabase auth). `user_id` columns added to `habits`, `groups`, `vacations`. |
| v7 | Phase 8 | `day_shields(id, day UNIQUE, applied_at)` + `idx_day_shields_day`. New settings keys `available_shields`, `shieldEarnInterval`, `last_seen_date`. |
| v8 | Phase 11 | `completions.updated_at`, `completions.deleted` — LWW + tombstone columns. Backfilled `updated_at = created_at`. |
| v9 | Phase 11 | `habits.updated_at`, `habits.deleted` — LWW + tombstone columns. Backfilled `updated_at = created_at`. |
| v10 | Phase 12 | `groups.updated_at`, `groups.deleted` — LWW + tombstone columns. Updated_at backfilled to now-in-seconds (Drift's `DateTime` storage convention). |
| v11 | Phase 12 | Recovery for a v10 bug that backfilled `groups.updated_at` in milliseconds (Drift reads as seconds → year-58000). Resets values > year-3000 threshold to 0 so the next pull restores valid timestamps from the server. |

---

## 7. Streak algorithm

Pure function. Lives in `domain/streaks.dart`. Inputs:
- `Habit habit`
- `List<Completion> completions` (sorted ascending by `day`)
- `DateTime today` (local midnight UTC)
- `List<DateRange> vacations` (active + past, used to mask out vacation days)

Outputs (record):

```dart
({int current, int pending, int longest, bool todayAtRisk, DateTime? streakStartUtc})
```

### Algorithm — per-habit streak (`computeStreaks`)

Shields do **not** affect per-habit streaks. Only `completions` and `vacations` determine a habit's streak.

1. Build the set of **completed days** from `completions`:
   - checkbox / health: `value >= 0.5` ≡ done.
   - counter / duration: `value >= target` ≡ done.
2. Walk forward day-by-day from `habit.startDate` through today, split at yesterday:
   - **Phase 1** (through yesterday): advances or resets `current`; records `pendingCurrent` and `pendingStart` after.
   - **Phase 2** (today): advances or resets `current`.
   - Vacation days: neutral (neither advance nor reset).
   - Not-due days: skip (neutral).
   - `streakStartUtc`: set to the first day of the current run, reset to null on any miss.
3. `todayAtRisk` = today is a due, non-vacation day with no completion yet.
4. `displayStreak = todayAtRisk ? pending : current`.

### Algorithm — overall day-wise streak (`computeOverallStreak`)

A day is **successful** when every due habit was completed OR a `day_shields` row exists for that day.

```
outcome(d):
  if d is vacation day → 0 (neutral)
  if day_shields contains d → 1 (success, regardless of completions)
  if all due habits completed → 1
  if no habits due → 0 (neutral)
  else → -1 (miss)
```

Walk forward from the earliest habit start (capped at 90 days for the in-memory window):
- outcome 1 → `current++`
- outcome -1 → `current = 0`
- outcome 0 → no change

### Shield application — forward-only rule

Shields are applied at the transition boundary (when a calendar day rolls from "today" to "yesterday"), not retroactively. The launch scan:

1. Read `last_seen_date` from settings.
2. For each day D from `last_seen_date + 1` to yesterday (chronological order):
   - Compute `outcome(D)` using completions only (no shields yet).
   - If outcome == -1 (miss) and `available_shields > 0`:
     - Insert `day_shields(day: D, applied_at: now)`.
     - Decrement `available_shields`.
   - If outcome == -1 and no shields available: day stays a miss, permanently.
3. Set `last_seen_date = today`.

Days before `last_seen_date` are never re-evaluated. Shields earned after a miss occurred do not retroactively heal it.

### Shield earning

After the launch scan, recompute `computeOverallStreak` (now including any newly inserted shields). Every time the streak crosses a multiple of `shieldEarnInterval` consecutive successful days, award 1 shield by incrementing `available_shields`. Track the last awarded boundary in the same scan to avoid double-awarding.

### Auto-recovery

When any completion is written or deleted, re-check whether the affected day now has 100% completion. If it does and a `day_shields` row exists for that day, delete the shield row and increment `available_shields` by 1.

### Test cases (must pass)

- 14-day continuous run → `current = 14`, 2 shields earned (at days 7 and 14).
- 14-day run, miss on day 8, shield available at transition → shield consumed, `current = 14`, 1 shield earned (day 7), 1 consumed.
- Same but no shield at transition → `current = 6` (streak broke at day 7), miss locked in.
- Shield earned on day 14 after day-8 miss was already locked → shield stays in pool, day 8 stays a miss.
- Vacation Mon–Fri inside a streak → streak unchanged, vacation days do not consume shields.
- Schedule = weekdays, missed Saturday → not a due day, neutral, no shield consumed.
- Back-fill a shielded day to 100% → `day_shields` row deleted, pool +1.

These cases are golden tests in `test/domain/streaks_test.dart`.

---

## 8. Repository surface

```dart
abstract class HabitRepository {
  Stream<List<Habit>> watchActive();
  Future<Habit> create(NewHabit input);
  Future<Habit> update(Habit habit);
  Future<void> archive(int id);
  Future<void> delete(int id);
}

abstract class CompletionRepository {
  Stream<Map<int, Completion>> watchForDay(DateTime localDay);   // habitId → completion
  Future<void> toggle(int habitId, DateTime localDay);            // checkbox
  Future<void> setValue(int habitId, DateTime localDay, double value);
  Stream<List<Completion>> watchForHabit(int habitId, {DateTime? since});
}

abstract class VacationRepository {
  Stream<Vacation?> watchActive();
  Stream<List<Vacation>> watchAll();
  Future<void> start(DateTime end, {String? note});
  Future<void> extend(DateTime newEnd);
  Future<void> endNow();
}
```

These are the only entry points into `data/`. UI never touches drift directly.

---

## 9. Export / import format

Settings → Data → Export produces:

```json
{
  "schema": 1,
  "exportedAt": "2026-05-07T18:23:11Z",
  "groups":      [ { "id": "...", "name": "...", "sortIndex": 100 } ],
  "habits":      [ { "id": 1, "groupId": "...", "name": "read", "tracking": "checkbox", ... } ],
  "completions": [ { "habitId": 1, "day": "2026-05-06T00:00:00Z", "value": 1.0 } ],
  "vacations":   [ { "start": "...", "end": "...", "note": null } ],
  "settings":    { "userName": "vivek", "themeId": "matrix", ... }
}
```

Import:
1. Validate `schema` == current.
2. Show preview (counts of each entity).
3. On confirm: open a transaction, truncate all tables, insert from import. No merge mode in v1.
4. On any error inside the transaction: rollback, show error, leave existing DB intact.

Sync (Phase 10) uses a different transport but the same logical shape per row.

---

## 10. Storage paths

| Platform | Path |
|---|---|
| macOS | `~/Library/Application Support/TerminalHabits/db.sqlite` |
| Linux | `~/.local/share/TerminalHabits/db.sqlite` |
| Android | `<app_internal_dir>/databases/db.sqlite` |

Resolved via `path_provider.getApplicationSupportDirectory()`. Never hard-code paths.

Backups live alongside as `db.sqlite.backup-${ISO8601}`. Created automatically on import (before truncate).
