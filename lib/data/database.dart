import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(
    tables: [Users, Groups, Habits, Completions, Vacations, AppSettings, HabitScheduleHistory, DayShields])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 9;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await customStatement(
              'CREATE INDEX idx_completions_day ON completions(day)');
          await customStatement(
              'CREATE INDEX idx_completions_habit_day ON completions(habit_id, day)');
          await customStatement(
              'CREATE INDEX idx_habits_group_sort ON habits(group_id, sort_index)');
          await customStatement(
              'CREATE INDEX idx_habits_archived ON habits(archived_at)');
          await customStatement(
              'CREATE INDEX idx_schedule_history_habit ON habit_schedule_history(habit_id, effective_from)');
          await _seedDefaults();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(groups, groups.note);
            await m.addColumn(habits, habits.targetTime);
          }
          if (from < 3) {
            await m.addColumn(habits, habits.startDate);
            await customStatement(
                'UPDATE habits SET start_date = created_at');
          }
          if (from < 4) {
            await m.addColumn(groups, groups.icon);
          }
          if (from < 5) {
            await m.createTable(habitScheduleHistory);
            await customStatement(
                'CREATE INDEX idx_schedule_history_habit ON habit_schedule_history(habit_id, effective_from)');
            await m.addColumn(habits, habits.endDate);
            final nowMs = DateTime.now().millisecondsSinceEpoch;
            await customStatement(
                'INSERT INTO habit_schedule_history (habit_id, effective_from, schedule, tracking, created_at) '
                'SELECT id, start_date, schedule, tracking, $nowMs FROM habits');
          }
          if (from < 6) {
            await m.createTable(users);
            await m.addColumn(groups, groups.userId);
            await m.addColumn(habits, habits.userId);
            await m.addColumn(vacations, vacations.userId);
            // Seed placeholder user so existing data (DEFAULT 1) has a valid owner.
            final existingName = await getSetting('userName') ?? 'user';
            final nowMs = DateTime.now().millisecondsSinceEpoch;
            await customStatement(
                "INSERT INTO users (id, username, display_name, password, created_at) "
                "VALUES (1, 'dev', '$existingName', 'dev', $nowMs)");
          }
          if (from < 7) {
            await m.createTable(dayShields);
            await customStatement(
                'CREATE INDEX idx_day_shields_day ON day_shields(day)');
            await _upsertSetting('available_shields', '0');
            await _upsertSetting('shieldEarnInterval', '7');
            await _upsertSetting('last_seen_date', '');
          }
          if (from < 8) {
            // m.addColumn() fails for non-constant defaults (CURRENT_TIMESTAMP).
            // Use raw SQL with a constant default, then backfill.
            await customStatement(
                'ALTER TABLE completions ADD COLUMN updated_at INTEGER NOT NULL DEFAULT 0');
            await customStatement(
                'ALTER TABLE completions ADD COLUMN deleted INTEGER NOT NULL DEFAULT 0');
            await customStatement(
                'UPDATE completions SET updated_at = created_at');
          }
          if (from < 9) {
            await customStatement(
                'ALTER TABLE habits ADD COLUMN updated_at INTEGER NOT NULL DEFAULT 0');
            await customStatement(
                'ALTER TABLE habits ADD COLUMN deleted INTEGER NOT NULL DEFAULT 0');
            await customStatement(
                'UPDATE habits SET updated_at = created_at');
          }
        },
      );

  Future<void> _seedDefaults() async {
    await into(groups).insertOnConflictUpdate(GroupsCompanion.insert(
      id: Value('general'),
      name: 'general',
      sortIndex: 100,
    ));
    await _upsertSetting('userName', 'you');
    await _upsertSetting('themeId', 'matrix');
    await _upsertSetting('fontSize', 'md');
    await _upsertSetting('fontFamily', 'JetBrains Mono');
    await _upsertSetting('lastView', 'daily');
    await _upsertSetting('seenOnboarding', 'false');
    await _upsertSetting('allowFutureMarking', 'false');
    await _upsertSetting('confirmDestructive', 'true');
    await _upsertSetting('available_shields', '0');
    await _upsertSetting('shieldEarnInterval', '7');
    await _upsertSetting('last_seen_date', '');
  }

  Future<void> _upsertSetting(String key, String value) async {
    await into(appSettings).insertOnConflictUpdate(
      AppSettingsCompanion.insert(key: key, value: value),
    );
  }

  // ── Users ──────────────────────────────────────────────────────────────────

  Future<int> createUser(
      String username, String displayName, String password) async {
    return into(users).insert(UsersCompanion.insert(
      username: username,
      displayName: displayName,
      password: password,
      createdAt: Value(DateTime.now()),
    ));
  }

  Future<User?> getUserByUsername(String username) =>
      (select(users)..where((u) => u.username.equals(username)))
          .getSingleOrNull();

  Future<User?> getUserById(int id) =>
      (select(users)..where((u) => u.id.equals(id))).getSingleOrNull();

  Future<int> getUserCount() => users.count().getSingle();

  Future<void> updateDisplayName(int userId, String displayName) =>
      (update(users)..where((u) => u.id.equals(userId)))
          .write(UsersCompanion(displayName: Value(displayName)));

  // Wipes all user-specific local data then re-seeds base structure.
  // Call on logout and before a new user starts.
  Future<void> clearAllUserData() async {
    await transaction(() async {
      await delete(completions).go();
      await delete(dayShields).go();
      await delete(habitScheduleHistory).go();
      await delete(habits).go();
      await delete(groups).go();
      await delete(vacations).go();
      await delete(appSettings).go();
      await delete(users).go();
    });
    await _seedDefaults();
  }

  // Creates the placeholder local user (id=1) if it doesn't exist, then
  // updates the username to match the Supabase-authenticated email.
  Future<void> ensurePlaceholderUser(String email) async {
    final existing = await getUserById(1);
    if (existing == null) {
      await customInsert(
        'INSERT OR IGNORE INTO users (id, username, display_name, password, created_at) VALUES (1, ?, ?, \'\', ?)',
        variables: [
          Variable.withString(email),
          Variable.withString(email.split('@').first),
          // Drift 2.x stores DateTimeColumn as unix seconds, not milliseconds.
          Variable.withInt(DateTime.now().millisecondsSinceEpoch ~/ 1000),
        ],
      );
      return;
    }
    if (existing.username != email) {
      await (update(users)..where((u) => u.id.equals(1)))
          .write(UsersCompanion(username: Value(email)));
    }
  }

  // ── Groups ─────────────────────────────────────────────────────────────────

  Stream<List<Group>> watchGroups(int userId) =>
      (select(groups)
            ..where((g) => g.userId.equals(userId))
            ..orderBy([(g) => OrderingTerm.asc(g.sortIndex)]))
          .watch();

  Future<List<Group>> getGroups(int userId) =>
      (select(groups)
            ..where((g) => g.userId.equals(userId))
            ..orderBy([(g) => OrderingTerm.asc(g.sortIndex)]))
          .get();

  Future<Group> createGroup(int userId, String name,
      {String? icon, String? note}) async {
    final existing = await (select(groups)
          ..where((g) => g.userId.equals(userId))
          ..orderBy([(g) => OrderingTerm.desc(g.sortIndex)])
          ..limit(1))
        .getSingleOrNull();
    final nextSort = (existing?.sortIndex ?? 0) + 100;
    final newId = newUuid();
    await into(groups).insert(GroupsCompanion.insert(
      id: Value(newId),
      userId: Value(userId),
      name: name,
      sortIndex: nextSort,
      icon: Value(icon),
      note: Value(note),
    ));
    return (select(groups)..where((g) => g.id.equals(newId))).getSingle();
  }

  Future<void> patchGroup(String groupId, GroupsCompanion companion) =>
      (update(groups)..where((g) => g.id.equals(groupId))).write(companion);

  Future<void> setGroupCollapsed(String groupId, bool collapsed) async {
    await (update(groups)..where((g) => g.id.equals(groupId)))
        .write(GroupsCompanion(collapsed: Value(collapsed)));
  }

  Future<void> setGroupNote(String groupId, String? note) async {
    await (update(groups)..where((g) => g.id.equals(groupId)))
        .write(GroupsCompanion(note: Value(note)));
  }

  Future<void> renameGroup(String groupId, String name) async {
    await (update(groups)..where((g) => g.id.equals(groupId)))
        .write(GroupsCompanion(name: Value(name)));
  }

  // Deletes [groupId]. Habits are reassigned to [reassignTo] if non-null;
  // otherwise the habits and their completions are cascade-deleted.
  Future<void> deleteGroup(String groupId, {String? reassignTo}) async {
    if (reassignTo != null) {
      await (update(habits)..where((h) => h.groupId.equals(groupId)))
          .write(HabitsCompanion(groupId: Value(reassignTo)));
    } else {
      final affected = await (select(habits)
            ..where((h) => h.groupId.equals(groupId)))
          .get();
      for (final h in affected) {
        await (delete(completions)..where((c) => c.habitId.equals(h.id))).go();
      }
      await (delete(habits)..where((h) => h.groupId.equals(groupId))).go();
    }
    await (delete(groups)..where((g) => g.id.equals(groupId))).go();
  }

  // ── Habits ─────────────────────────────────────────────────────────────────

  Future<List<Habit>> getAllHabits(int userId) =>
      (select(habits)..where((h) => h.userId.equals(userId))
        ..orderBy([(h) => OrderingTerm.asc(h.sortIndex)]))
      .get();

  Future<List<Completion>> getAllCompletions() =>
      (select(completions)..orderBy([(c) => OrderingTerm.asc(c.id)])).get();

  Future<List<Completion>> getRecentCompletionsList(DateTime sinceUtc) =>
      (select(completions)
        ..where((c) =>
            c.day.isBiggerOrEqualValue(sinceUtc) & c.deleted.equals(false))
        ..orderBy([(c) => OrderingTerm.asc(c.day)]))
      .get();

  Stream<List<Habit>> watchActiveHabits(int userId) => (select(habits)
        ..where((h) =>
            h.userId.equals(userId) &
            h.archivedAt.isNull() &
            h.deleted.equals(false))
        ..orderBy([
          (h) => OrderingTerm.asc(h.groupId),
          (h) => OrderingTerm.asc(h.sortIndex),
        ]))
      .watch();

  Future<List<Habit>> getActiveHabits(int userId) => (select(habits)
        ..where((h) =>
            h.userId.equals(userId) &
            h.archivedAt.isNull() &
            h.deleted.equals(false))
        ..orderBy([
          (h) => OrderingTerm.asc(h.groupId),
          (h) => OrderingTerm.asc(h.sortIndex),
        ]))
      .get();

  Future<Habit> getHabit(int id) =>
      (select(habits)..where((h) => h.id.equals(id))).getSingle();

  Future<int> createHabit(HabitsCompanion companion) async {
    // Always supply createdAt as an integer so Drift can read it back safely.
    // withDefault(currentDateAndTime) writes SQLite's CURRENT_TIMESTAMP (text),
    // which Drift's integer-mode DateTime reader then fails to parse.
    final now = DateTime.now();
    final id = await into(habits)
        .insert(companion.copyWith(createdAt: Value(now), updatedAt: Value(now)));
    final startDate = companion.startDate.value;
    await _insertHistoryRow(
        id, startDate.toUtc(), companion.schedule.value, companion.tracking.value);
    return id;
  }

  Future<bool> updateHabit(HabitsCompanion companion) =>
      update(habits).replace(companion);

  // Partial update: writes only the fields supplied in [companion].
  // Use this from the edit dialog so we don't overwrite columns the dialog
  // doesn't surface (e.g. completion-related state).
  Future<int> patchHabit(int id, HabitsCompanion companion) =>
      (update(habits)..where((h) => h.id.equals(id)))
          .write(companion.copyWith(updatedAt: Value(DateTime.now())));

  Future<void> archiveHabit(int id) async {
    final now = DateTime.now();
    await (update(habits)..where((h) => h.id.equals(id)))
        .write(HabitsCompanion(archivedAt: Value(now), updatedAt: Value(now)));
  }

  Future<void> unarchiveHabit(int id) async {
    await (update(habits)..where((h) => h.id.equals(id)))
        .write(HabitsCompanion(
            archivedAt: const Value(null), updatedAt: Value(DateTime.now())));
  }

  Stream<List<Habit>> watchArchivedHabits(int userId) => (select(habits)
        ..where((h) =>
            h.userId.equals(userId) &
            h.archivedAt.isNotNull() &
            h.deleted.equals(false))
        ..orderBy([(h) => OrderingTerm.desc(h.archivedAt)]))
      .watch();

  Future<void> deleteHabit(int id) async {
    // Soft-delete so the deletion propagates via sync (row stays for LWW diff).
    await (update(habits)..where((h) => h.id.equals(id)))
        .write(HabitsCompanion(
            deleted: const Value(true), updatedAt: Value(DateTime.now())));
  }

  // ── Schedule history ────────────────────────────────────────────────────────

  Stream<List<HabitScheduleHistoryData>> watchScheduleHistory(int habitId) =>
      (select(habitScheduleHistory)
            ..where((r) => r.habitId.equals(habitId))
            ..orderBy([
              (r) => OrderingTerm.desc(r.effectiveFrom),
              (r) => OrderingTerm.desc(r.id),
            ]))
          .watch();

  Future<List<HabitScheduleHistoryData>> getScheduleHistory(int habitId) =>
      (select(habitScheduleHistory)
            ..where((r) => r.habitId.equals(habitId))
            ..orderBy([
              (r) => OrderingTerm.desc(r.effectiveFrom),
              (r) => OrderingTerm.desc(r.id),
            ]))
          .get();

  // Adds a new history row for [habitId] effective from [effectiveFrom].
  // Replaces any existing row with the same (habitId, effectiveFrom) so that
  // repeated same-day edits never leave stale duplicate entries.
  Future<void> appendScheduleHistory(
      int habitId, DateTime effectiveFrom, String schedule, String tracking) async {
    await (delete(habitScheduleHistory)
          ..where((r) =>
              r.habitId.equals(habitId) &
              r.effectiveFrom.equals(effectiveFrom)))
        .go();
    await _insertHistoryRow(habitId, effectiveFrom, schedule, tracking);
  }

  // Replaces all history for [habitId] with a single row from [effectiveFrom].
  // Call this when the user chooses "overwrite" or when no completions exist.
  Future<void> replaceScheduleHistory(
      int habitId, DateTime effectiveFrom, String schedule, String tracking) async {
    await (delete(habitScheduleHistory)
          ..where((r) => r.habitId.equals(habitId)))
        .go();
    await _insertHistoryRow(habitId, effectiveFrom, schedule, tracking);
  }

  Future<void> _insertHistoryRow(
      int habitId, DateTime effectiveFrom, String schedule, String tracking) =>
      into(habitScheduleHistory).insert(HabitScheduleHistoryCompanion.insert(
        habitId: habitId,
        effectiveFrom: effectiveFrom,
        schedule: schedule,
        tracking: tracking,
        createdAt: Value(DateTime.now()),
      ));

  // Returns all history records grouped by habitId (desc effective_from, desc id).
  Future<Map<int, List<HabitScheduleHistoryData>>> getAllScheduleHistory() async {
    final rows = await (select(habitScheduleHistory)
          ..orderBy([
            (r) => OrderingTerm.desc(r.effectiveFrom),
            (r) => OrderingTerm.desc(r.id),
          ]))
        .get();
    final map = <int, List<HabitScheduleHistoryData>>{};
    for (final r in rows) (map[r.habitId] ??= []).add(r);
    return map;
  }

  Stream<Map<int, List<HabitScheduleHistoryData>>> watchAllScheduleHistory() =>
      (select(habitScheduleHistory)
            ..orderBy([
              (r) => OrderingTerm.desc(r.effectiveFrom),
              (r) => OrderingTerm.desc(r.id),
            ]))
          .watch()
          .map((rows) {
        final map = <int, List<HabitScheduleHistoryData>>{};
        for (final r in rows) (map[r.habitId] ??= []).add(r);
        return map;
      });

  // ── Completions ────────────────────────────────────────────────────────────

  Stream<List<Completion>> watchCompletionsForDay(DateTime dayUtc) =>
      (select(completions)
            ..where((c) => c.day.equals(dayUtc) & c.deleted.equals(false)))
          .watch();

  Stream<List<Completion>> watchRecentCompletions(DateTime sinceUtc) =>
      (select(completions)
            ..where((c) =>
                c.day.isBiggerOrEqualValue(sinceUtc) &
                c.deleted.equals(false)))
          .watch();

  Future<List<Completion>> getCompletionsForHabit(int habitId) =>
      (select(completions)
            ..where((c) =>
                c.habitId.equals(habitId) & c.deleted.equals(false))
            ..orderBy([(c) => OrderingTerm.asc(c.day)]))
          .get();

  Future<void> toggleCompletion(int habitId, DateTime dayUtc) async {
    final existing = await (select(completions)
          ..where((c) =>
              c.habitId.equals(habitId) & c.day.equals(dayUtc)))
        .getSingleOrNull();
    final now = DateTime.now();
    if (existing != null && !existing.deleted) {
      // Uncheck: soft-delete, stamp updatedAt so LWW sync knows this is newer.
      await (update(completions)..where((c) => c.id.equals(existing.id)))
          .write(CompletionsCompanion(
            deleted: const Value(true),
            updatedAt: Value(now),
          ));
    } else if (existing != null) {
      // Reactivate a previously soft-deleted row.
      await (update(completions)..where((c) => c.id.equals(existing.id)))
          .write(CompletionsCompanion(
            value: const Value(1.0),
            deleted: const Value(false),
            updatedAt: Value(now),
          ));
    } else {
      // Insert a new completion row.
      await into(completions).insert(CompletionsCompanion.insert(
        habitId: habitId,
        day: dayUtc,
        value: const Value(1.0),
        createdAt: Value(now),
        updatedAt: Value(now),
        deleted: const Value(false),
      ));
    }
  }

  Future<void> setCompletionValue(
      int habitId, DateTime dayUtc, double value) async {
    final existing = await (select(completions)
          ..where((c) =>
              c.habitId.equals(habitId) &
              c.day.equals(dayUtc) &
              c.deleted.equals(false)))
        .getSingleOrNull();
    final now = DateTime.now();
    if (existing != null) {
      await (update(completions)..where((c) => c.id.equals(existing.id)))
          .write(CompletionsCompanion(value: Value(value), updatedAt: Value(now)));
    } else {
      await into(completions).insert(CompletionsCompanion.insert(
        habitId: habitId,
        day: dayUtc,
        value: Value(value),
        createdAt: Value(now),
        updatedAt: Value(now),
      ));
    }
  }

  Future<void> clearCompletion(int habitId, DateTime dayUtc) async {
    await (delete(completions)
          ..where((c) =>
              c.habitId.equals(habitId) & c.day.equals(dayUtc)))
        .go();
  }

  // Deletes all completions for [habitId] and resets schedule history to a
  // single row starting at [startDateUtc]. Call when type or schedule changes.
  Future<void> clearHabitProgress(
      int habitId, DateTime startDateUtc, String schedule, String tracking) async {
    await (delete(completions)..where((c) => c.habitId.equals(habitId))).go();
    await replaceScheduleHistory(habitId, startDateUtc, schedule, tracking);
  }

  // Deletes all completions for [habitId] with day strictly before [cutoffUtc].
  Future<void> clearCompletionsBefore(int habitId, DateTime cutoffUtc) async {
    await (delete(completions)
          ..where((c) =>
              c.habitId.equals(habitId) &
              c.day.isSmallerThanValue(cutoffUtc)))
        .go();
  }

  // Deletes completions for [habitId] whose local weekday (0=Mon..6=Sun) is
  // in [deleteWeekdays]. Used when narrowing a schedule to remove completions
  // on days that are no longer tracked.
  Future<void> clearCompletionsOnDays(
      int habitId, Set<int> deleteWeekdays) async {
    if (deleteWeekdays.isEmpty) return;
    final comps = await getCompletionsForHabit(habitId);
    final ids = comps
        .where((c) =>
            deleteWeekdays.contains((c.day.toLocal().weekday + 6) % 7))
        .map((c) => c.id)
        .toList();
    if (ids.isEmpty) return;
    await (delete(completions)..where((c) => c.id.isIn(ids))).go();
  }

  Future<void> incrementCompletion(
      int habitId, DateTime dayUtc, double delta) async {
    final existing = await (select(completions)
          ..where((c) =>
              c.habitId.equals(habitId) &
              c.day.equals(dayUtc) &
              c.deleted.equals(false)))
        .getSingleOrNull();
    final now = DateTime.now();
    final newValue = (existing?.value ?? 0.0) + delta;
    if (existing != null) {
      await (update(completions)..where((c) => c.id.equals(existing.id)))
          .write(CompletionsCompanion(
            value: Value(newValue),
            deleted: const Value(false),
            updatedAt: Value(now),
          ));
    } else {
      await into(completions).insert(CompletionsCompanion.insert(
        habitId: habitId,
        day: dayUtc,
        value: Value(newValue),
        createdAt: Value(now),
        updatedAt: Value(now),
        deleted: const Value(false),
      ));
    }
  }

  // ── Vacations ──────────────────────────────────────────────────────────────

  Stream<List<Vacation>> watchVacations(int userId) =>
      (select(vacations)
            ..where((v) => v.userId.equals(userId))
            ..orderBy([(v) => OrderingTerm.desc(v.start)]))
          .watch();

  Future<List<Vacation>> getVacations(int userId) =>
      (select(vacations)
            ..where((v) => v.userId.equals(userId))
            ..orderBy([(v) => OrderingTerm.asc(v.start)]))
          .get();

  Future<Vacation?> getActiveVacation(int userId) =>
      (select(vacations)
            ..where((v) => v.userId.equals(userId) & v.active.equals(true))
            ..limit(1))
          .getSingleOrNull();

  Future<void> startVacation(
      int userId, DateTime start, DateTime end, {String? note}) async {
    await into(vacations).insert(VacationsCompanion.insert(
      userId: Value(userId),
      start: start,
      end: end,
      note: Value(note),
      active: const Value(true),
    ));
  }

  Future<void> extendVacation(int id, DateTime newEnd) =>
      (update(vacations)..where((v) => v.id.equals(id)))
          .write(VacationsCompanion(end: Value(newEnd)));

  Future<void> editVacation(int id, DateTime newStart, DateTime newEnd) =>
      (update(vacations)..where((v) => v.id.equals(id)))
          .write(VacationsCompanion(start: Value(newStart), end: Value(newEnd)));

  Future<bool> hasCompletionsInRange(
      List<int> habitIds, DateTime startUtc, DateTime endUtc) async {
    if (habitIds.isEmpty) return false;
    final result = await (select(completions)
          ..where((c) =>
              c.habitId.isIn(habitIds) &
              c.day.isBiggerOrEqualValue(startUtc) &
              c.day.isSmallerOrEqualValue(endUtc) &
              c.deleted.equals(false))
          ..limit(1))
        .getSingleOrNull();
    return result != null;
  }

  Future<void> endVacationNow(int id) async {
    final vac = await (select(vacations)
          ..where((v) => v.id.equals(id)))
        .getSingleOrNull();
    if (vac == null) return;
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day - 1).toUtc();
    final origLocal = vac.end.toLocal();
    final origEnd =
        DateTime(origLocal.year, origLocal.month, origLocal.day).toUtc();
    // Only cap end to yesterday if the vacation extends past yesterday.
    // Past-only vacations keep their original end so historical streak days
    // are not accidentally included in the vacation window.
    await (update(vacations)..where((v) => v.id.equals(id))).write(
      VacationsCompanion(
        active: const Value(false),
        end: origEnd.isAfter(yesterday) ? Value(yesterday) : const Value.absent(),
      ),
    );
  }

  Future<void> deleteVacation(int id) =>
      (delete(vacations)..where((v) => v.id.equals(id))).go();

  // ── Day shields ────────────────────────────────────────────────────────────

  Stream<List<DayShield>> watchDayShields(DateTime sinceUtc) =>
      (select(dayShields)
            ..where((s) => s.day.isBiggerOrEqualValue(sinceUtc))
            ..orderBy([(s) => OrderingTerm.asc(s.day)]))
          .watch();

  Future<List<DayShield>> getAllDayShields() =>
      (select(dayShields)..orderBy([(s) => OrderingTerm.asc(s.day)])).get();

  Future<void> insertDayShield(DateTime dayUtc) async {
    await into(dayShields).insertOnConflictUpdate(
      DayShieldsCompanion.insert(
        day: dayUtc,
        appliedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> deleteDayShield(DateTime dayUtc) =>
      (delete(dayShields)..where((s) => s.day.equals(dayUtc))).go();

  Future<int> getAvailableShields() async =>
      int.tryParse(await getSetting('available_shields') ?? '0') ?? 0;

  Future<void> setAvailableShields(int n) =>
      setSetting('available_shields', n.toString());

  // ── Settings ───────────────────────────────────────────────────────────────

  Future<String?> getSetting(String key) async {
    final row = await (select(appSettings)
          ..where((s) => s.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> setSetting(String key, String value) =>
      _upsertSetting(key, value);

  Stream<String?> watchSetting(String key) => (select(appSettings)
        ..where((s) => s.key.equals(key)))
      .watchSingleOrNull()
      .map((row) => row?.value);
}

// Opens the database at the platform-appropriate path.
Future<AppDatabase> openAppDatabase() async {
  final dir = await getApplicationSupportDirectory();
  final file = File(p.join(dir.path, 'db.sqlite'));
  return AppDatabase(NativeDatabase(file));
}
