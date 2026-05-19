import 'package:drift/drift.dart' show Value;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'database.dart';

class SyncService {
  final AppDatabase _db;
  SyncService(this._db);

  SupabaseClient get _c => Supabase.instance.client;
  String get _uid => _c.auth.currentUser!.id;

  // ── Push (local → Supabase) ────────────────────────────────────────────────

  Future<void> pushAll() async {
    await _pushGroups();
    await _pushHabits();
    await _pushHistory();
    await _pushCompletions();
    await _pushVacations();
    await _pushShields();
  }

  Future<void> _pushGroups() async {
    final rows = await _db.getGroups(1);
    if (rows.isEmpty) return;
    await _c.from('groups').upsert(rows.map((g) => {
          'id': g.id,
          'user_id': _uid,
          'name': g.name,
          'sort_index': g.sortIndex,
          'collapsed': g.collapsed,
          'note': g.note,
          'icon': g.icon,
        }).toList());
  }

  Future<void> _pushHabits() async {
    final rows = await _db.getAllHabits(1);
    if (rows.isEmpty) return;
    await _c.from('habits').upsert(rows.map((h) => {
          'id': h.id,
          'user_id': _uid,
          'group_id': h.groupId,
          'name': h.name,
          'icon': h.icon,
          'color': h.color,
          'tracking': h.tracking,
          'target': h.target,
          'unit': h.unit,
          'schedule': h.schedule,
          'note': h.note,
          'target_time': h.targetTime,
          'sort_index': h.sortIndex,
          'health_source': h.healthSource,
          'created_at': h.createdAt.millisecondsSinceEpoch,
          'start_date': h.startDate.millisecondsSinceEpoch,
          'end_date': h.endDate?.millisecondsSinceEpoch,
          'archived_at': h.archivedAt?.millisecondsSinceEpoch,
        }).toList());
  }

  Future<void> _pushHistory() async {
    final map = await _db.getAllScheduleHistory();
    final rows = map.values.expand((v) => v).toList();
    if (rows.isEmpty) return;
    await _c.from('habit_schedule_history').upsert(rows.map((r) => {
          'id': r.id,
          'user_id': _uid,
          'habit_id': r.habitId,
          'effective_from': r.effectiveFrom.millisecondsSinceEpoch,
          'schedule': r.schedule,
          'tracking': r.tracking,
          'created_at': r.createdAt.millisecondsSinceEpoch,
        }).toList());
  }

  Future<void> _pushCompletions() async {
    final rows = await _db.getAllCompletions();
    if (rows.isEmpty) return;
    // Batch in chunks of 500 to stay within request size limits.
    for (var i = 0; i < rows.length; i += 500) {
      final batch = rows.sublist(i, (i + 500).clamp(0, rows.length));
      await _c.from('completions').upsert(batch.map((c) => {
            'id': c.id,
            'user_id': _uid,
            'habit_id': c.habitId,
            'day': c.day.millisecondsSinceEpoch,
            'value': c.value,
            'created_at': c.createdAt.millisecondsSinceEpoch,
          }).toList());
    }
  }

  Future<void> _pushVacations() async {
    final rows = await _db.getVacations(1);
    if (rows.isEmpty) return;
    await _c.from('vacations').upsert(rows.map((v) => {
          'id': v.id,
          'user_id': _uid,
          'start_ts': v.start.millisecondsSinceEpoch,
          'end_ts': v.end.millisecondsSinceEpoch,
          'active': v.active,
          'note': v.note,
        }).toList());
  }

  Future<void> _pushShields() async {
    final rows = await _db.getAllDayShields();
    if (rows.isEmpty) return;
    await _c.from('day_shields').upsert(rows.map((s) => {
          'id': s.id,
          'user_id': _uid,
          'day': s.day.millisecondsSinceEpoch,
          'applied_at': s.appliedAt.millisecondsSinceEpoch,
        }).toList());
  }

  // ── Pull (Supabase → local) ────────────────────────────────────────────────

  // Replaces all local synced data with server state.
  // Skips if the server has no data yet (prevents wiping local on first sync).
  Future<void> pullAll() async {
    final serverGroups = await _c.from('groups').select().eq('user_id', _uid)
        as List<dynamic>;
    final serverHabits = await _c.from('habits').select().eq('user_id', _uid)
        as List<dynamic>;
    final serverHistory = await _c
        .from('habit_schedule_history')
        .select()
        .eq('user_id', _uid) as List<dynamic>;
    final serverCompletions = await _c
        .from('completions')
        .select()
        .eq('user_id', _uid) as List<dynamic>;
    final serverVacations =
        await _c.from('vacations').select().eq('user_id', _uid) as List<dynamic>;
    final serverShields = await _c
        .from('day_shields')
        .select()
        .eq('user_id', _uid) as List<dynamic>;

    // If server is completely empty, user hasn't pushed yet — don't wipe local.
    if (serverGroups.isEmpty && serverHabits.isEmpty && serverCompletions.isEmpty) {
      return;
    }

    await _db.transaction(() async {
      // Delete local synced data (Users table is never touched).
      await _db.delete(_db.completions).go();
      await _db.delete(_db.dayShields).go();
      await _db.delete(_db.habitScheduleHistory).go();
      await _db.delete(_db.habits).go();
      await _db.delete(_db.groups).go();
      await _db.delete(_db.vacations).go();

      // Re-insert from server.
      for (final r in serverGroups) {
        await _db.into(_db.groups).insert(GroupsCompanion(
              id: Value(r['id'] as String),
              userId: const Value(1),
              name: Value(r['name'] as String),
              sortIndex: Value(r['sort_index'] as int),
              collapsed: Value(r['collapsed'] as bool? ?? false),
              note: Value(r['note'] as String?),
              icon: Value(r['icon'] as String?),
            ));
      }

      for (final r in serverHabits) {
        await _db.into(_db.habits).insert(HabitsCompanion(
              id: Value((r['id'] as num).toInt()),
              userId: const Value(1),
              groupId: Value(r['group_id'] as String),
              name: Value(r['name'] as String),
              icon: Value(r['icon'] as String? ?? '●'),
              color: Value(r['color'] as String? ?? 'green'),
              tracking: Value(r['tracking'] as String),
              target: Value(r['target'] as int?),
              unit: Value(r['unit'] as String?),
              schedule: Value(r['schedule'] as String),
              note: Value(r['note'] as String?),
              targetTime: Value(r['target_time'] as String?),
              sortIndex: Value(r['sort_index'] as int),
              healthSource: Value(r['health_source'] as String?),
              createdAt: Value(_ms(r['created_at'])),
              startDate: Value(_ms(r['start_date'])),
              endDate: Value(r['end_date'] != null ? _ms(r['end_date']) : null),
              archivedAt:
                  Value(r['archived_at'] != null ? _ms(r['archived_at']) : null),
            ));
      }

      for (final r in serverHistory) {
        await _db.into(_db.habitScheduleHistory).insert(
              HabitScheduleHistoryCompanion(
                id: Value((r['id'] as num).toInt()),
                habitId: Value((r['habit_id'] as num).toInt()),
                effectiveFrom: Value(_ms(r['effective_from'])),
                schedule: Value(r['schedule'] as String),
                tracking: Value(r['tracking'] as String),
                createdAt: Value(_ms(r['created_at'])),
              ),
            );
      }

      for (final r in serverCompletions) {
        await _db.into(_db.completions).insert(CompletionsCompanion(
              id: Value((r['id'] as num).toInt()),
              habitId: Value((r['habit_id'] as num).toInt()),
              day: Value(_ms(r['day'])),
              value: Value((r['value'] as num).toDouble()),
              createdAt: Value(_ms(r['created_at'])),
            ));
      }

      for (final r in serverVacations) {
        await _db.into(_db.vacations).insert(VacationsCompanion(
              id: Value((r['id'] as num).toInt()),
              userId: const Value(1),
              start: Value(_ms(r['start_ts'])),
              end: Value(_ms(r['end_ts'])),
              active: Value(r['active'] as bool? ?? false),
              note: Value(r['note'] as String?),
            ));
      }

      for (final r in serverShields) {
        await _db.into(_db.dayShields).insert(DayShieldsCompanion(
              id: Value((r['id'] as num).toInt()),
              day: Value(_ms(r['day'])),
              appliedAt: Value(r['applied_at'] != null
                  ? _ms(r['applied_at'])
                  : DateTime.now().toUtc()),
            ));
      }
    });
  }

  DateTime _ms(dynamic ms) =>
      DateTime.fromMillisecondsSinceEpoch((ms as num).toInt(), isUtc: true);
}
