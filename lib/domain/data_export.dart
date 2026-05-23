import 'dart:convert';
import 'package:drift/drift.dart' show Value, Insertable, TableInfo, Table;
import 'package:uuid/uuid.dart';
import '../data/database.dart';
import '../app_info.dart';

const _uuid = Uuid();

/// Local backup format. Versioned by the Drift `schemaVersion` so an import
/// against a mismatched schema fails fast instead of silently corrupting
/// data.
///
/// Import is a **merge**, not a replace:
///   - Groups: matched by name. Existing local group reused; new groups
///     created with a fresh UUID.
///   - Habits: matched by name. On conflict, the caller chooses `replace`
///     (soft-delete the local habit + its completions, insert the JSON's
///     version with a fresh auto-increment id) or `keepLocal` (skip the
///     JSON's habit and its completions entirely).
///   - Completions: inserted with `habitId` remapped through the habit-id
///     mapping built during habit import.
///   - History: same remap.
///   - Vacations, shields: appended as-is (no remap needed).
///   - app_settings: skipped (device-local, not imported).
///
/// Imported rows that carry `updatedAt` are stamped to `now()` so a
/// subsequent push wins LWW against the existing server state.

class ExportEnvelope {
  static const int currentSchema = 11;
}

enum ImportConflictResolution { replace, keepLocal }

class ImportError implements Exception {
  final String message;
  ImportError(this.message);
  @override
  String toString() => 'ImportError: $message';
}

class ImportResult {
  final int groupsAdded;
  final int habitsReplaced;
  final int habitsAdded;
  final int habitsSkipped;
  final int completionsAdded;
  final int historyAdded;
  final int vacationsAdded;
  final int shieldsAdded;
  const ImportResult({
    required this.groupsAdded,
    required this.habitsReplaced,
    required this.habitsAdded,
    required this.habitsSkipped,
    required this.completionsAdded,
    required this.historyAdded,
    required this.vacationsAdded,
    required this.shieldsAdded,
  });
}

Future<String> exportAllToJson(AppDatabase db) async {
  final groups      = await db.getAllGroups(1);
  final habits      = await db.getAllHabits(1);
  final histMap     = await db.getAllScheduleHistory();
  final history     = histMap.values.expand((v) => v).toList();
  final completions = await db.getAllCompletions();
  final vacations   = await db.getVacations(1);
  final shields     = await db.getAllDayShields();
  final settings    = await db.allSettings();

  final out = <String, dynamic>{
    'schema': ExportEnvelope.currentSchema,
    'exportedAt': DateTime.now().toUtc().toIso8601String(),
    'appVersion': kAppVersion,
    'groups':       groups.map((r) => r.toJson()).toList(),
    'habits':       habits.map((r) => r.toJson()).toList(),
    'history':      history.map((r) => r.toJson()).toList(),
    'completions':  completions.map((r) => r.toJson()).toList(),
    'vacations':    vacations.map((r) => r.toJson()).toList(),
    'day_shields':  shields.map((r) => r.toJson()).toList(),
    'app_settings': settings.map((r) => r.toJson()).toList(),
  };
  return const JsonEncoder.withIndent('  ').convert(out);
}

/// Parses the JSON and returns the list of habit names that conflict with
/// existing (non-deleted) local habits. Caller uses this to prompt the
/// user before deciding the conflict resolution.
Future<List<String>> peekImportConflicts(
    AppDatabase db, String jsonStr) async {
  final root = _parseAndValidate(jsonStr);
  final habits = _rowsFromRoot(root, 'habits');
  final localHabits = await db.getActiveHabits(1);
  final localByName = {for (final h in localHabits) h.name: h};
  final conflicts = <String>[];
  for (final j in habits) {
    final name = j['name'] as String?;
    if (name == null) continue;
    if (localByName.containsKey(name)) conflicts.add(name);
  }
  return conflicts;
}

Future<ImportResult> importFromJson(
  AppDatabase db,
  String jsonStr, {
  required ImportConflictResolution conflictResolution,
}) async {
  final root = _parseAndValidate(jsonStr);

  final groupsJson      = _rowsFromRoot(root, 'groups');
  final habitsJson      = _rowsFromRoot(root, 'habits');
  final historyJson     = _rowsFromRoot(root, 'history');
  final completionsJson = _rowsFromRoot(root, 'completions');
  final vacationsJson   = _rowsFromRoot(root, 'vacations');
  final shieldsJson     = _rowsFromRoot(root, 'day_shields');

  final nowIso = DateTime.now().toUtc().toIso8601String();

  int groupsAdded = 0;
  int habitsReplaced = 0;
  int habitsAdded = 0;
  int habitsSkipped = 0;
  int completionsAdded = 0;
  int historyAdded = 0;
  int vacationsAdded = 0;
  int shieldsAdded = 0;

  await db.transaction(() async {
    // ── Groups: match by name; reuse local id when name matches ──
    final localGroups = await db.getGroups(1); // active only
    final localGroupByName = {for (final g in localGroups) g.name: g};
    final localGroupById = {for (final g in localGroups) g.id: g};
    final groupIdMap = <String, String>{};
    for (final jg in groupsJson) {
      final name = jg['name'] as String? ?? '';
      final jsonId = jg['id'] as String? ?? '';
      if (name.isEmpty || jsonId.isEmpty) continue;
      final existing = localGroupByName[name];
      if (existing != null) {
        groupIdMap[jsonId] = existing.id;
        continue;
      }
      // No name conflict — insert the JSON group. Keep its id unless it
      // happens to collide with an unrelated local group id.
      final useId = localGroupById.containsKey(jsonId) ? _uuid.v4() : jsonId;
      jg['id'] = useId;
      jg['updatedAt'] = nowIso;
      await db.into(db.groups).insertOnConflictUpdate(
          Group.fromJson(jg).toCompanion(false));
      groupIdMap[jsonId] = useId;
      groupsAdded++;
    }

    // ── Habits: match by name; user-chosen resolution on conflicts ──
    final localActiveHabits = await db.getActiveHabits(1);
    final localHabitByName = {
      for (final h in localActiveHabits) h.name: h,
    };
    final habitIdMap = <int, int>{}; // jsonHabitId → newLocalHabitId
    for (final jh in habitsJson) {
      final name = jh['name'] as String? ?? '';
      final jsonHabitId = jh['id'] as int? ?? -1;
      if (name.isEmpty || jsonHabitId < 0) continue;

      // Re-map groupId via the groups mapping (or fall back to general).
      final jsonGroupId = jh['groupId'] as String? ?? 'general';
      jh['groupId'] = groupIdMap[jsonGroupId] ?? 'general';
      jh['updatedAt'] = nowIso;

      final conflict = localHabitByName[name];
      if (conflict != null) {
        if (conflictResolution == ImportConflictResolution.keepLocal) {
          habitsSkipped++;
          continue; // don't add to mapping → completions for this habit skipped
        }
        // Replace: soft-delete the local habit + its completions so the
        // tombstones propagate via sync, then insert the JSON's version
        // with a fresh local id.
        await (db.update(db.habits)..where((h) => h.id.equals(conflict.id)))
            .write(HabitsCompanion(
              deleted: const Value(true),
              updatedAt: Value(DateTime.now()),
            ));
        await (db.update(db.completions)
              ..where((c) => c.habitId.equals(conflict.id)))
            .write(CompletionsCompanion(
              deleted: const Value(true),
              updatedAt: Value(DateTime.now()),
            ));
        habitsReplaced++;
      } else {
        habitsAdded++;
      }

      // Insert the JSON's habit with a fresh local autoincrement id.
      final companion = Habit.fromJson(jh).toCompanion(false).copyWith(
            id: const Value.absent(),
          );
      final newId = await db.into(db.habits).insert(companion);
      habitIdMap[jsonHabitId] = newId;
    }

    // ── Completions: remap habitId, insert fresh ──
    for (final jc in completionsJson) {
      final oldHabitId = jc['habitId'] as int? ?? -1;
      final newHabitId = habitIdMap[oldHabitId];
      if (newHabitId == null) continue; // habit was kept-local, skip
      jc['habitId'] = newHabitId;
      jc['updatedAt'] = nowIso;
      final companion = Completion.fromJson(jc).toCompanion(false).copyWith(
            id: const Value.absent(),
          );
      // insertOnConflictUpdate guards against (habit_id, day) UNIQUE if a
      // run lands twice for some reason.
      await db.into(db.completions).insertOnConflictUpdate(companion);
      completionsAdded++;
    }

    // ── Schedule history: remap habitId, insert fresh ──
    for (final jr in historyJson) {
      final oldHabitId = jr['habitId'] as int? ?? -1;
      final newHabitId = habitIdMap[oldHabitId];
      if (newHabitId == null) continue;
      jr['habitId'] = newHabitId;
      final companion = HabitScheduleHistoryData.fromJson(jr)
          .toCompanion(false)
          .copyWith(id: const Value.absent());
      await db.into(db.habitScheduleHistory).insert(companion);
      historyAdded++;
    }

    // ── Vacations: standalone, append. Fresh id to avoid collision. ──
    for (final jv in vacationsJson) {
      final companion = Vacation.fromJson(jv)
          .toCompanion(false)
          .copyWith(id: const Value.absent());
      await db.into(db.vacations).insert(companion);
      vacationsAdded++;
    }

    // ── Shields: standalone. UNIQUE on `day` — upsert in case the same
    // calendar day was already shielded locally. ──
    for (final js in shieldsJson) {
      final companion = DayShield.fromJson(js)
          .toCompanion(false)
          .copyWith(id: const Value.absent());
      await db.into(db.dayShields).insertOnConflictUpdate(companion);
      shieldsAdded++;
    }

    // app_settings intentionally skipped — local settings are device-local.
  });

  return ImportResult(
    groupsAdded: groupsAdded,
    habitsReplaced: habitsReplaced,
    habitsAdded: habitsAdded,
    habitsSkipped: habitsSkipped,
    completionsAdded: completionsAdded,
    historyAdded: historyAdded,
    vacationsAdded: vacationsAdded,
    shieldsAdded: shieldsAdded,
  );
}

Map<String, dynamic> _parseAndValidate(String jsonStr) {
  late final Map<String, dynamic> root;
  try {
    root = jsonDecode(jsonStr) as Map<String, dynamic>;
  } catch (_) {
    throw ImportError('file is not valid JSON.');
  }
  final schema = root['schema'];
  if (schema is! int) {
    throw ImportError('missing "schema" field.');
  }
  if (schema != ExportEnvelope.currentSchema) {
    throw ImportError(
        'schema mismatch: file is v$schema, app expects v${ExportEnvelope.currentSchema}.');
  }
  return root;
}

List<Map<String, dynamic>> _rowsFromRoot(
    Map<String, dynamic> root, String key) {
  final v = root[key];
  if (v == null) return [];
  if (v is! List) throw ImportError('"$key" must be a list.');
  return v.cast<Map<String, dynamic>>();
}

// Unused helper retained from earlier signature; kept for the importer's
// optional generic-table path in case we add more imported tables later.
// ignore: unused_element
Future<void> _upsertAll<T extends Insertable<Object?>>(
  AppDatabase db,
  TableInfo<Table, Object?> table,
  List<Map<String, dynamic>> rows,
  T Function(Map<String, dynamic>) fromJson,
) async {
  for (final j in rows) {
    await db.into(table).insertOnConflictUpdate(fromJson(j));
  }
}
