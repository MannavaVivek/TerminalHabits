import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(tables: [Groups, Habits, Completions, Vacations, AppSettings])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 4;

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
        },
      );

  Future<void> _seedDefaults() async {
    await into(groups).insert(GroupsCompanion.insert(
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
  }

  Future<void> _upsertSetting(String key, String value) async {
    await into(appSettings).insertOnConflictUpdate(
      AppSettingsCompanion.insert(key: key, value: value),
    );
  }

  // ── Groups ─────────────────────────────────────────────────────────────────

  Stream<List<Group>> watchGroups() =>
      (select(groups)..orderBy([(g) => OrderingTerm.asc(g.sortIndex)])).watch();

  Future<List<Group>> getGroups() =>
      (select(groups)..orderBy([(g) => OrderingTerm.asc(g.sortIndex)])).get();

  Future<Group> createGroup(String name,
      {String? icon, String? note}) async {
    final existing = await (select(groups)
          ..orderBy([(g) => OrderingTerm.desc(g.sortIndex)])
          ..limit(1))
        .getSingleOrNull();
    final nextSort = (existing?.sortIndex ?? 0) + 100;
    final newId = newUuid();
    await into(groups).insert(GroupsCompanion.insert(
      id: Value(newId),
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

  Stream<List<Habit>> watchActiveHabits() => (select(habits)
        ..where((h) => h.archivedAt.isNull())
        ..orderBy([
          (h) => OrderingTerm.asc(h.groupId),
          (h) => OrderingTerm.asc(h.sortIndex),
        ]))
      .watch();

  Future<List<Habit>> getActiveHabits() => (select(habits)
        ..where((h) => h.archivedAt.isNull())
        ..orderBy([
          (h) => OrderingTerm.asc(h.groupId),
          (h) => OrderingTerm.asc(h.sortIndex),
        ]))
      .get();

  Future<Habit> getHabit(int id) =>
      (select(habits)..where((h) => h.id.equals(id))).getSingle();

  Future<int> createHabit(HabitsCompanion companion) =>
      into(habits).insert(companion);

  Future<bool> updateHabit(HabitsCompanion companion) =>
      update(habits).replace(companion);

  // Partial update: writes only the fields supplied in [companion].
  // Use this from the edit dialog so we don't overwrite columns the dialog
  // doesn't surface (e.g. completion-related state).
  Future<int> patchHabit(int id, HabitsCompanion companion) =>
      (update(habits)..where((h) => h.id.equals(id))).write(companion);

  Future<void> archiveHabit(int id) async {
    await (update(habits)..where((h) => h.id.equals(id)))
        .write(HabitsCompanion(archivedAt: Value(DateTime.now())));
  }

  Future<void> unarchiveHabit(int id) async {
    await (update(habits)..where((h) => h.id.equals(id)))
        .write(const HabitsCompanion(archivedAt: Value(null)));
  }

  Stream<List<Habit>> watchArchivedHabits() => (select(habits)
        ..where((h) => h.archivedAt.isNotNull())
        ..orderBy([(h) => OrderingTerm.desc(h.archivedAt)]))
      .watch();

  Future<void> deleteHabit(int id) async {
    await (delete(completions)..where((c) => c.habitId.equals(id))).go();
    await (delete(habits)..where((h) => h.id.equals(id))).go();
  }

  // ── Completions ────────────────────────────────────────────────────────────

  Stream<List<Completion>> watchCompletionsForDay(DateTime dayUtc) =>
      (select(completions)..where((c) => c.day.equals(dayUtc))).watch();

  Stream<List<Completion>> watchRecentCompletions(DateTime sinceUtc) =>
      (select(completions)
            ..where((c) => c.day.isBiggerOrEqualValue(sinceUtc)))
          .watch();

  Future<List<Completion>> getCompletionsForHabit(int habitId) =>
      (select(completions)
            ..where((c) => c.habitId.equals(habitId))
            ..orderBy([(c) => OrderingTerm.asc(c.day)]))
          .get();

  Future<void> toggleCompletion(int habitId, DateTime dayUtc) async {
    final existing = await (select(completions)
          ..where((c) =>
              c.habitId.equals(habitId) & c.day.equals(dayUtc)))
        .getSingleOrNull();
    if (existing != null) {
      await (delete(completions)..where((c) => c.id.equals(existing.id))).go();
    } else {
      await into(completions).insert(CompletionsCompanion.insert(
        habitId: habitId,
        day: dayUtc,
      ));
    }
  }

  Future<void> setCompletionValue(
      int habitId, DateTime dayUtc, double value) async {
    await into(completions).insertOnConflictUpdate(CompletionsCompanion.insert(
      habitId: habitId,
      day: dayUtc,
      value: Value(value),
    ));
  }

  Future<void> clearCompletion(int habitId, DateTime dayUtc) async {
    await (delete(completions)
          ..where((c) =>
              c.habitId.equals(habitId) & c.day.equals(dayUtc)))
        .go();
  }

  Future<void> incrementCompletion(
      int habitId, DateTime dayUtc, double delta) async {
    final existing = await (select(completions)
          ..where((c) =>
              c.habitId.equals(habitId) & c.day.equals(dayUtc)))
        .getSingleOrNull();
    final newValue = (existing?.value ?? 0.0) + delta;
    await into(completions).insertOnConflictUpdate(CompletionsCompanion.insert(
      habitId: habitId,
      day: dayUtc,
      value: Value(newValue),
    ));
  }

  // ── Vacations ──────────────────────────────────────────────────────────────

  Stream<List<Vacation>> watchVacations() =>
      (select(vacations)..orderBy([(v) => OrderingTerm.desc(v.start)]))
          .watch();

  Future<List<Vacation>> getVacations() =>
      (select(vacations)..orderBy([(v) => OrderingTerm.asc(v.start)])).get();

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
