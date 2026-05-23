import 'dart:convert';
import 'package:drift/drift.dart' show Insertable;
import '../data/database.dart';
import '../app_info.dart';

/// Local backup format. Versioned by the Drift `schemaVersion` so an import
/// against a mismatched schema fails fast instead of silently corrupting
/// data. Intentionally simple — `toJson`/`fromJson` on each Drift row plus
/// a small envelope.
///
/// Cloud sync (Supabase) is NOT touched by import/export. Import is
/// expected while signed out; signing back in afterward will pull server
/// data and overwrite the import, so the caller is responsible for that
/// gate.

class ExportEnvelope {
  static const int currentSchema = 11;

  static String exportedAtKey = 'exportedAt';
  static String appVersionKey = 'appVersion';
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

class ImportError implements Exception {
  final String message;
  ImportError(this.message);
  @override
  String toString() => 'ImportError: $message';
}

class ImportResult {
  final int groups;
  final int habits;
  final int completions;
  final int history;
  final int vacations;
  final int shields;
  final int settings;
  const ImportResult({
    required this.groups,
    required this.habits,
    required this.completions,
    required this.history,
    required this.vacations,
    required this.shields,
    required this.settings,
  });
}

Future<ImportResult> importFromJson(AppDatabase db, String jsonStr) async {
  late final Map<String, dynamic> root;
  try {
    root = jsonDecode(jsonStr) as Map<String, dynamic>;
  } catch (e) {
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

  List<Map<String, dynamic>> _rows(String key) {
    final v = root[key];
    if (v == null) return const [];
    if (v is! List) {
      throw ImportError('"$key" must be a list.');
    }
    return v.cast<Map<String, dynamic>>();
  }

  final groups      = _rows('groups');
  final habits      = _rows('habits');
  final history     = _rows('history');
  final completions = _rows('completions');
  final vacations   = _rows('vacations');
  final shields     = _rows('day_shields');
  final settings    = _rows('app_settings');

  // clearAllUserData wipes every user-scoped table and reseeds the default
  // 'general' group + setting keys. The reseeded rows will be upserted by
  // the loops below if the JSON provides them; otherwise the defaults
  // remain (which is fine for a settings-only-partial export).
  await db.clearAllUserData();

  await db.transaction(() async {
    Future<void> upsertAll<T extends Insertable<Object?>>(
      TableInfo<Table, Object?> table,
      List<Map<String, dynamic>> rows,
      T Function(Map<String, dynamic>) fromJson,
    ) async {
      for (final j in rows) {
        await db.into(table).insertOnConflictUpdate(fromJson(j));
      }
    }

    // Parents first.
    await upsertAll(db.groups, groups,
        (j) => Group.fromJson(j).toCompanion(false));
    await upsertAll(db.habits, habits,
        (j) => Habit.fromJson(j).toCompanion(false));
    await upsertAll(db.habitScheduleHistory, history,
        (j) => HabitScheduleHistoryData.fromJson(j).toCompanion(false));
    await upsertAll(db.completions, completions,
        (j) => Completion.fromJson(j).toCompanion(false));
    await upsertAll(db.vacations, vacations,
        (j) => Vacation.fromJson(j).toCompanion(false));
    await upsertAll(db.dayShields, shields,
        (j) => DayShield.fromJson(j).toCompanion(false));
    await upsertAll(db.appSettings, settings,
        (j) => AppSetting.fromJson(j).toCompanion(false));
  });

  return ImportResult(
    groups: groups.length,
    habits: habits.length,
    completions: completions.length,
    history: history.length,
    vacations: vacations.length,
    shields: shields.length,
    settings: settings.length,
  );
}
