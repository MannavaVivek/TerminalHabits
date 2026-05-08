# Data Model — TerminalHabits

> Drift schema, indexes, migrations, and the streak algorithm. This is the contract every persistence and computation layer adheres to. Behavior in [feature_spec.md](feature_spec.md) is implemented against this shape.

---

## 1. Tables (drift)

```dart
// Groups
class Groups extends Table {
  TextColumn  get id        => text().clientDefault(_uuid)();   // uuid v4
  TextColumn  get name      => text()();
  IntColumn   get sortIndex => integer()();
  BoolColumn  get collapsed => boolean().withDefault(const Constant(false))();

  @override Set<Column> get primaryKey => {id};
}

// Habits
class Habits extends Table {
  IntColumn      get id         => integer().autoIncrement()();
  TextColumn     get groupId    => text().references(Groups, #id)();
  TextColumn     get name       => text()();
  TextColumn     get icon       => text().withDefault(const Constant('●'))();
  TextColumn     get color      => text().withDefault(const Constant('green'))();
  TextColumn     get tracking   => text()();   // 'checkbox' | 'count' | 'number' | 'health'
  IntColumn      get target     => integer().nullable()();   // for count/number
  TextColumn     get unit       => text().nullable()();      // for number, e.g. "min"
  TextColumn     get schedule   => text()();   // JSON: {"days":[0..6]}
  TextColumn     get note       => text().nullable()();
  IntColumn      get sortIndex  => integer()();
  TextColumn     get healthSource => text().nullable()();    // for tracking='health'
  DateTimeColumn get createdAt    => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get archivedAt   => dateTime().nullable()();
}

// Completions — one row per (habit, day) when nonzero
class Completions extends Table {
  IntColumn      get id        => integer().autoIncrement()();
  IntColumn      get habitId   => integer().references(Habits, #id)();
  DateTimeColumn get day       => dateTime()();   // local-midnight UTC
  RealColumn     get value     => real().withDefault(const Constant(1.0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override List<Set<Column>> get uniqueKeys => [{habitId, day}];
}

// Vacations — one active at a time, plus history
class Vacations extends Table {
  IntColumn      get id      => integer().autoIncrement()();
  DateTimeColumn get start   => dateTime()();
  DateTimeColumn get end     => dateTime()();
  TextColumn     get note    => text().nullable()();
  BoolColumn     get active  => boolean().withDefault(const Constant(false))();
}

// Settings — single-row "key/value" sidecar
class Settings extends Table {
  TextColumn get key   => text()();
  TextColumn get value => text()();   // JSON-encoded

  @override Set<Column> get primaryKey => {key};
}
```

### Settings keys (canonical)

| Key | Value type | Default |
|---|---|---|
| `userName` | string | `"you"` |
| `themeId` | enum | `"matrix"` |
| `fontSize` | enum xs/sm/md/lg | `"md"` |
| `fontFamily` | string | `"JetBrainsMono"` |
| `defaultGroupId` | string | first-created group id |
| `seenSplash` | bool | `false` |
| `lastView` | enum daily/stats/profile | `"daily"` |

`shared_preferences` is used **only** for `seenSplash` (because it must be readable before the DB opens). Everything else lives in `Settings`.

---

## 2. Indexes

```dart
// In drift @DriftDatabase migration:
await m.createIndex(Index('idx_completions_day', 'CREATE INDEX idx_completions_day ON completions(day)'));
await m.createIndex(Index('idx_completions_habit_day', 'CREATE INDEX idx_completions_habit_day ON completions(habit_id, day)'));
await m.createIndex(Index('idx_habits_group_sort', 'CREATE INDEX idx_habits_group_sort ON habits(group_id, sort_index)'));
await m.createIndex(Index('idx_habits_archived', 'CREATE INDEX idx_habits_archived ON habits(archived_at)'));
```

Stats queries scan completions by date range; the `(habit_id, day)` composite handles streak recomputation efficiently.

---

## 3. Day boundary & timezone handling

- Every `Completion.day` is the UTC instant of **local midnight on the day the user checked the habit.**
- Computation: `final day = DateTime(now.year, now.month, now.day).toUtc();`
- This means moving to a new timezone shifts which "day" yesterday's completion belongs to. That's intentional and matches user intuition: a 11pm completion in NYC stays "yesterday" if you fly to LA overnight.
- DST transitions: the DateTime constructor handles the skipped/repeated hour correctly; we never compute days as `epoch_seconds / 86400`.
- All comparisons in queries use `>= start_of_day_utc AND < start_of_next_day_utc` (no `BETWEEN`).

---

## 4. Schedule encoding

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

## 5. Migrations

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
| v4 | Phase 4 | `groups.icon TEXT NULL` (backfilled `'▸'`). `habits.icon` reused for the curated picker — no schema change there. |
| v5 | Phase 5 | `habit_schedule_history(id, habit_id, effective_from, schedule, tracking, created_at)` with `(habit_id, effective_from DESC)` index. Backfills one row per habit. After v5, `habits.schedule` and `habits.tracking` mirror the most-recent history row. |

---

## 6. Streak algorithm

Pure function. Lives in `domain/streaks.dart`. Inputs:
- `Habit habit`
- `List<Completion> completions` (sorted ascending by `day`)
- `DateTime today` (local midnight UTC)
- `List<DateRange> vacations` (active + past, used to mask out vacation days)

Outputs (record):

```dart
({int current, int longest, int shields})
```

### Algorithm

1. Build the set of **completed days** = `{c.day for c in completions if c.value > 0 OR (tracking != count/number)}`.
   - For checkbox: `value > 0` ≡ done.
   - For count/number: `value >= target` ≡ done. `0 < value < target` is *partial* and does **not** count toward streak.
   - For health: `value >= target` ≡ done.
2. Build the set of **due days** for this habit, going backward from today:
   - A day D is due if `isHabitDueOn(habit, D)` is true AND D is not within any vacation range.
3. Walk backward day-by-day from today:
   - If today is due: streak counts from today backwards across consecutive due-and-completed days.
   - If today is not due: streak count is whatever the most recent completed run was (don't penalize for not-due-today).
4. **Shield consumption:** when walking backward you encounter a missed due day, check if a shield can absorb it.
   - Shields are earned at every 7-consecutive-completed-due-day boundary.
   - Each 7-day window (rolling) can have at most one shield consumed.
   - If a shield is available, treat that missed day as completed and continue.
   - If not, terminate the streak walk.
5. **Longest:** scan all due days from `habit.createdAt` forward, tracking the maximum consecutive run with the same shield rules.
6. **Current shields surplus:** total earned shields minus total consumed.

### Test cases (must pass)

- 14-day continuous run, no misses → `current = 14, shields = 2`.
- 14-day run with one miss on day 6 (shield absorbs) → `current = 14, shields = 1`.
- 14-day run with two misses inside one week → second miss breaks streak.
- Schedule = weekdays, missed Sat → no streak break.
- Vacation Mon–Fri inside a streak → streak unchanged.

These cases are golden tests in `test/domain/streaks_test.dart` and gate Phase 1 exit.

---

## 7. Repository surface

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

## 8. Export / import format

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

Sync (Phase 11) uses a different transport but the same logical shape per row.

---

## 9. Storage paths

| Platform | Path |
|---|---|
| macOS | `~/Library/Application Support/TerminalHabits/db.sqlite` |
| Linux | `~/.local/share/TerminalHabits/db.sqlite` |
| Android | `<app_internal_dir>/databases/db.sqlite` |

Resolved via `path_provider.getApplicationSupportDirectory()`. Never hard-code paths.

Backups live alongside as `db.sqlite.backup-${ISO8601}`. Created automatically on import (before truncate).
