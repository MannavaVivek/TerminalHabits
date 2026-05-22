import 'dart:async';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'database.dart';

class SyncService {
  final AppDatabase _db;
  SyncService(this._db);

  SupabaseClient get _c => Supabase.instance.client;
  String get _uid => _c.auth.currentUser!.id;

  // True while a pull is active + 3s cooldown after it completes.
  // AppScaffold checks this before scheduling a push.
  static bool isPulling = false;
  static Timer? _pullCooldown;

  static RealtimeChannel? _channel;

  // Completes after the first post-login pullAll finishes (success or failure).
  // The launch shield scan awaits this so it doesn't operate on stale local
  // data. Reset by stopRealtime() on logout.
  static Completer<void>? _initialPullCompleter;
  static Future<void> get initialPullCompleted async =>
      _initialPullCompleter?.future ?? Future<void>.value();

  // ── Push (local → Supabase) ────────────────────────────────────────────────
  // Diff-based: upserts all local rows and deletes server rows absent locally.
  // No table wipes — safe against concurrent pushes from another device.

  Future<void> pushAll() async {
    final localGroups      = await _db.getAllGroups(1);
    final localHabits      = await _db.getAllHabits(1);
    final localHistMap     = await _db.getAllScheduleHistory();
    final localHistory     = localHistMap.values.expand((v) => v).toList();
    final localCompletions = await _db.getAllCompletions();
    final localVacations   = await _db.getVacations(1);
    final localShields     = await _db.getAllDayShields();

    // Fetch server ID sets (lightweight — id column only).
    final sHistoryIds  = await _serverIntIds('habit_schedule_history');
    final sVacationIds = await _serverIntIds('vacations');
    final sShieldIds   = await _serverIntIds('day_shields');
    // Habits, completions, and groups use LWW — fetch id+updated_at.
    final sHabitTs      = await _serverHabitTimestamps();
    final sCompletionTs = await _serverCompletionTimestamps();
    final sGroupTs      = await _serverGroupTimestamps();

    // Rows on server but not local = hard-deleted by user (history, vacations,
    // shields). Habits, completions, and groups use soft-delete so tombstones
    // stay in local; diff only fires for hard-deletes (e.g. schedule changes).
    final delCompletions = sCompletionTs.keys.toSet().difference(localCompletions.map((c) => c.id).toSet());
    final delShields     = sShieldIds.difference(localShields.map((s) => s.id).toSet());
    final delHistory     = sHistoryIds.difference(localHistory.map((r) => r.id).toSet());
    final delHabits      = sHabitTs.keys.toSet().difference(localHabits.map((h) => h.id).toSet());
    final delVacations   = sVacationIds.difference(localVacations.map((v) => v.id).toSet());

    if (delCompletions.isNotEmpty) await _c.from('completions').delete().inFilter('id', delCompletions.toList());
    if (delShields.isNotEmpty)     await _c.from('day_shields').delete().inFilter('id', delShields.toList());
    if (delHistory.isNotEmpty)     await _c.from('habit_schedule_history').delete().inFilter('id', delHistory.toList());
    if (delHabits.isNotEmpty)      await _c.from('habits').delete().inFilter('id', delHabits.toList());
    if (delVacations.isNotEmpty)   await _c.from('vacations').delete().inFilter('id', delVacations.toList());

    // Upsert local groups (LWW — only push rows newer than server).
    final groupsToUpsert = localGroups.where((g) {
      final serverTs = sGroupTs[g.id];
      if (serverTs == null) return true;
      return g.updatedAt.isAfter(serverTs);
    }).toList();
    if (groupsToUpsert.isNotEmpty) {
      await _c.from('groups').upsert(groupsToUpsert.map((g) => {
        'id': g.id, 'user_id': _uid, 'name': g.name,
        'sort_index': g.sortIndex, 'collapsed': g.collapsed,
        'note': g.note, 'icon': g.icon,
        'updated_at': g.updatedAt.millisecondsSinceEpoch,
        'deleted': g.deleted,
      }).toList());
    }
    // Only push habits where local updatedAt is newer than server (LWW).
    final habitsToUpsert = localHabits.where((h) {
      final serverTs = sHabitTs[h.id];
      if (serverTs == null) return true;
      return h.updatedAt.isAfter(serverTs);
    }).toList();
    if (habitsToUpsert.isNotEmpty) {
      await _c.from('habits').upsert(habitsToUpsert.map((h) => {
        'id': h.id, 'user_id': _uid, 'group_id': h.groupId,
        'name': h.name, 'icon': h.icon, 'color': h.color,
        'tracking': h.tracking, 'target': h.target, 'unit': h.unit,
        'schedule': h.schedule, 'note': h.note, 'target_time': h.targetTime,
        'sort_index': h.sortIndex, 'health_source': h.healthSource,
        'created_at': h.createdAt.millisecondsSinceEpoch,
        'start_date': h.startDate.millisecondsSinceEpoch,
        'end_date': h.endDate?.millisecondsSinceEpoch,
        'archived_at': h.archivedAt?.millisecondsSinceEpoch,
        'updated_at': h.updatedAt.millisecondsSinceEpoch,
        'deleted': h.deleted,
      }).toList());
    }
    if (localHistory.isNotEmpty) {
      await _c.from('habit_schedule_history').upsert(localHistory.map((r) => {
        'id': r.id, 'user_id': _uid, 'habit_id': r.habitId,
        'effective_from': r.effectiveFrom.millisecondsSinceEpoch,
        'schedule': r.schedule, 'tracking': r.tracking,
        'created_at': r.createdAt.millisecondsSinceEpoch,
      }).toList());
    }
    // Only push completions where local updatedAt is newer than server (LWW).
    final compsToUpsert = localCompletions.where((c) {
      final serverTs = sCompletionTs[c.id];
      if (serverTs == null) return true; // new locally, push it
      return c.updatedAt.isAfter(serverTs);
    }).toList();
    if (compsToUpsert.isNotEmpty) {
      for (var i = 0; i < compsToUpsert.length; i += 500) {
        final batch = compsToUpsert.sublist(i, (i + 500).clamp(0, compsToUpsert.length));
        await _c.from('completions').upsert(batch.map((c) => {
          'id': c.id, 'user_id': _uid, 'habit_id': c.habitId,
          'day': c.day.millisecondsSinceEpoch, 'value': c.value,
          'created_at': c.createdAt.millisecondsSinceEpoch,
          'updated_at': c.updatedAt.millisecondsSinceEpoch,
          'deleted': c.deleted,
        }).toList());
      }
    }
    if (localVacations.isNotEmpty) {
      await _c.from('vacations').upsert(localVacations.map((v) => {
        'id': v.id, 'user_id': _uid,
        'start_ts': v.start.millisecondsSinceEpoch,
        'end_ts': v.end.millisecondsSinceEpoch,
        'active': v.active, 'note': v.note,
      }).toList());
    }
    if (localShields.isNotEmpty) {
      await _c.from('day_shields').upsert(localShields.map((s) => {
        'id': s.id, 'user_id': _uid,
        'day': s.day.millisecondsSinceEpoch,
        'applied_at': s.appliedAt.millisecondsSinceEpoch,
      }).toList());
    }
  }

  // ── Pull (Supabase → local) ────────────────────────────────────────────────
  // Upsert-based: applies server state without wiping local first.
  // Local rows absent from server are deleted (removed on another device).

  Future<bool> pullAll() async {
    isPulling = true;
    _pullCooldown?.cancel();
    try {
      return await _pullAllInner();
    } finally {
      _pullCooldown = Timer(const Duration(seconds: 3), () => isPulling = false);
    }
  }

  Future<bool> _pullAllInner() async {
    final serverGroups      = await _c.from('groups').select().eq('user_id', _uid) as List<dynamic>;
    final serverHabits      = await _c.from('habits').select().eq('user_id', _uid) as List<dynamic>;
    final serverHistory     = await _c.from('habit_schedule_history').select().eq('user_id', _uid) as List<dynamic>;
    final serverCompletions = await _c.from('completions').select().eq('user_id', _uid) as List<dynamic>;
    final serverVacations   = await _c.from('vacations').select().eq('user_id', _uid) as List<dynamic>;
    final serverShields     = await _c.from('day_shields').select().eq('user_id', _uid) as List<dynamic>;

    // Skip if server has no habits — fresh account or another device's push is
    // mid-flight (deleted but not yet reinserted). Wiping local on an empty
    // snapshot would destroy data.
    if (serverHabits.isEmpty) return false;

    final sHabitIds      = serverHabits.map((r) => (r['id'] as num).toInt()).toSet();
    final sHistoryIds    = serverHistory.map((r) => (r['id'] as num).toInt()).toSet();
    final sCompletionIds = serverCompletions.map((r) => (r['id'] as num).toInt()).toSet();
    final sVacationIds   = serverVacations.map((r) => (r['id'] as num).toInt()).toSet();
    final sShieldIds     = serverShields.map((r) => (r['id'] as num).toInt()).toSet();

    await _db.transaction(() async {
      // Delete local rows absent from server (FK-safe: children first).
      final lCompletions = await _db.getAllCompletions();
      final delC = lCompletions.where((c) => !sCompletionIds.contains(c.id)).map((c) => c.id).toList();
      if (delC.isNotEmpty) await (_db.delete(_db.completions)..where((c) => c.id.isIn(delC))).go();

      final lShields = await _db.getAllDayShields();
      final delS = lShields.where((s) => !sShieldIds.contains(s.id)).map((s) => s.id).toList();
      if (delS.isNotEmpty) await (_db.delete(_db.dayShields)..where((s) => s.id.isIn(delS))).go();

      final lHistMap = await _db.getAllScheduleHistory();
      final lHistory = lHistMap.values.expand((v) => v).toList();
      final delH = lHistory.where((r) => !sHistoryIds.contains(r.id)).map((r) => r.id).toList();
      if (delH.isNotEmpty) await (_db.delete(_db.habitScheduleHistory)..where((r) => r.id.isIn(delH))).go();

      final lHabits = await _db.getAllHabits(1);
      final delHa = lHabits.where((h) => !sHabitIds.contains(h.id)).map((h) => h.id).toList();
      if (delHa.isNotEmpty) await (_db.delete(_db.habits)..where((h) => h.id.isIn(delHa))).go();

      // Groups use soft-delete — don't hard-delete local groups missing from
      // server (the server's deleted=true tombstone arrives via the upsert
      // step below).

      final lVacations = await _db.getVacations(1);
      final delV = lVacations.where((v) => !sVacationIds.contains(v.id)).map((v) => v.id).toList();
      if (delV.isNotEmpty) await (_db.delete(_db.vacations)..where((v) => v.id.isIn(delV))).go();

      // Upsert server rows (parents first). LWW for groups: skip server rows
      // older than local.
      final lGroupsAll = await _db.getAllGroups(1);
      final lGroupTs = { for (final g in lGroupsAll) g.id: g.updatedAt };
      for (final r in serverGroups) {
        final gid = r['id'] as String;
        final serverUpdatedAt = _safeUpdatedAt(r['updated_at']);
        final localUpdatedAt = lGroupTs[gid];
        if (localUpdatedAt != null && localUpdatedAt.isAfter(serverUpdatedAt)) {
          continue;
        }
        await _db.into(_db.groups).insertOnConflictUpdate(GroupsCompanion(
          id: Value(gid),
          userId: const Value(1),
          name: Value(r['name'] as String),
          sortIndex: Value(r['sort_index'] as int),
          collapsed: Value(r['collapsed'] as bool? ?? false),
          note: Value(r['note'] as String?),
          icon: Value(r['icon'] as String?),
          updatedAt: Value(serverUpdatedAt),
          deleted: Value(r['deleted'] as bool? ?? false),
        ));
      }
      // Build local updatedAt map for LWW comparison.
      final lHabitsAll = await _db.getAllHabits(1);
      final lHabitTs = { for (final h in lHabitsAll) h.id: h.updatedAt };

      for (final r in serverHabits) {
        final id = (r['id'] as num).toInt();
        final serverUpdatedAt = r['updated_at'] != null
            ? _ms(r['updated_at'])
            : _ms(r['created_at']);
        final localUpdatedAt = lHabitTs[id];
        if (localUpdatedAt != null && localUpdatedAt.isAfter(serverUpdatedAt)) continue;
        await _db.into(_db.habits).insertOnConflictUpdate(HabitsCompanion(
          id: Value(id),
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
          archivedAt: Value(r['archived_at'] != null ? _ms(r['archived_at']) : null),
          updatedAt: Value(serverUpdatedAt),
          deleted: Value(r['deleted'] as bool? ?? false),
        ));
      }
      for (final r in serverHistory) {
        await _db.into(_db.habitScheduleHistory).insertOnConflictUpdate(
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
      // Build local updatedAt map for LWW comparison.
      final lCompsAll = await _db.getAllCompletions();
      final lCompTs = { for (final c in lCompsAll) c.id: c.updatedAt };

      for (final r in serverCompletions) {
        final id = (r['id'] as num).toInt();
        final serverUpdatedAt = r['updated_at'] != null
            ? _ms(r['updated_at'])
            : _ms(r['created_at']);
        final localUpdatedAt = lCompTs[id];
        // Skip if local is newer — this device's change wins.
        if (localUpdatedAt != null && localUpdatedAt.isAfter(serverUpdatedAt)) continue;
        await _db.into(_db.completions).insertOnConflictUpdate(CompletionsCompanion(
          id: Value(id),
          habitId: Value((r['habit_id'] as num).toInt()),
          day: Value(_ms(r['day'])),
          value: Value((r['value'] as num).toDouble()),
          createdAt: Value(_ms(r['created_at'])),
          updatedAt: Value(serverUpdatedAt),
          deleted: Value(r['deleted'] as bool? ?? false),
        ));
      }
      for (final r in serverVacations) {
        await _db.into(_db.vacations).insertOnConflictUpdate(VacationsCompanion(
          id: Value((r['id'] as num).toInt()),
          userId: const Value(1),
          start: Value(_ms(r['start_ts'])),
          end: Value(_ms(r['end_ts'])),
          active: Value(r['active'] as bool? ?? false),
          note: Value(r['note'] as String?),
        ));
      }
      for (final r in serverShields) {
        await _db.into(_db.dayShields).insertOnConflictUpdate(DayShieldsCompanion(
          id: Value((r['id'] as num).toInt()),
          day: Value(_ms(r['day'])),
          appliedAt: Value(r['applied_at'] != null
              ? _ms(r['applied_at'])
              : DateTime.now().toUtc()),
        ));
      }
    });

    return true;
  }

  // ── Realtime ────────────────────────────────────────────────────────────────
  // Subscribes to Postgres changes so this device updates automatically when
  // another device pushes. Call startRealtime() after login, stopRealtime() on
  // logout.
  //
  // Requires Realtime enabled for each table in Supabase:
  //   Dashboard → Database → Replication → supabase_realtime → add each table.
  // Or run once in SQL Editor:
  //   ALTER PUBLICATION supabase_realtime ADD TABLE
  //     habits, completions, groups, vacations,
  //     habit_schedule_history, day_shields;

  static void startRealtime(AppDatabase db) {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    stopRealtime();

    _initialPullCompleter = Completer<void>();
    _channel = Supabase.instance.client.channel('habit-sync-$uid');

    for (final table in ['habits', 'completions', 'groups', 'vacations',
                         'habit_schedule_history', 'day_shields']) {
      _channel!.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: uid,
        ),
        callback: (p) => _applyChange(db, table, p),
      );
    }

    _channel!.subscribe((status, [error]) {
      debugPrint('Realtime $status ${error ?? ''}');
      // On (re)connect, do a catch-up pull in case events were missed.
      if (status == RealtimeSubscribeStatus.subscribed) {
        SyncService(db).pullAll().then((_) {
          _completeInitialPull();
        }).catchError((Object e) {
          debugPrint('catch-up pull: $e');
          _completeInitialPull();
          return false;
        });
      }
    });
  }

  static void _completeInitialPull() {
    final c = _initialPullCompleter;
    if (c != null && !c.isCompleted) c.complete();
  }

  static void stopRealtime() {
    _channel?.unsubscribe();
    _channel = null;
    // Reset so the next login waits afresh.
    _initialPullCompleter = null;
  }

  static void _applyChange(AppDatabase db, String table, PostgresChangePayload p) {
    _applyChangeAsync(db, table, p)
        .catchError((Object e) => debugPrint('Realtime apply ($table): $e'));
  }

  static Future<void> _applyChangeAsync(AppDatabase db, String table, PostgresChangePayload p) async {
    if (p.eventType == PostgresChangeEvent.delete) {
      await _deleteLocalRow(db, table, p.oldRecord);
    } else {
      await _upsertLocalRow(db, table, p.newRecord);
    }
  }

  static Future<void> _upsertLocalRow(AppDatabase db, String table, Map<String, dynamic> r) async {
    switch (table) {
      case 'groups':
        final gid = r['id'] as String;
        final gServerTs = _safeUpdatedAtStatic(r['updated_at']);
        final gExisting = await (db.select(db.groups)
              ..where((g) => g.id.equals(gid)))
            .getSingleOrNull();
        if (gExisting != null && gExisting.updatedAt.isAfter(gServerTs)) break;
        await db.into(db.groups).insertOnConflictUpdate(GroupsCompanion(
          id: Value(gid),
          userId: const Value(1),
          name: Value(r['name'] as String),
          sortIndex: Value(r['sort_index'] as int),
          collapsed: Value(r['collapsed'] as bool? ?? false),
          note: Value(r['note'] as String?),
          icon: Value(r['icon'] as String?),
          updatedAt: Value(gServerTs),
          deleted: Value(r['deleted'] as bool? ?? false),
        ));
      case 'habits':
        final hId = (r['id'] as num).toInt();
        final hServerTs = r['updated_at'] != null
            ? _msStatic(r['updated_at'])
            : _msStatic(r['created_at']);
        final hExisting = await (db.select(db.habits)
              ..where((h) => h.id.equals(hId)))
            .getSingleOrNull();
        if (hExisting != null && hExisting.updatedAt.isAfter(hServerTs)) break;
        await db.into(db.habits).insertOnConflictUpdate(HabitsCompanion(
          id: Value(hId),
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
          createdAt: Value(_msStatic(r['created_at'])),
          startDate: Value(_msStatic(r['start_date'])),
          endDate: Value(r['end_date'] != null ? _msStatic(r['end_date']) : null),
          archivedAt: Value(r['archived_at'] != null ? _msStatic(r['archived_at']) : null),
          updatedAt: Value(hServerTs),
          deleted: Value(r['deleted'] as bool? ?? false),
        ));
      case 'completions':
        final id = (r['id'] as num).toInt();
        final serverUpdatedAt = r['updated_at'] != null
            ? _msStatic(r['updated_at'])
            : _msStatic(r['created_at']);
        // LWW: only apply if this Realtime event is newer than local.
        final existing = await (db.select(db.completions)
              ..where((c) => c.id.equals(id)))
            .getSingleOrNull();
        if (existing != null && existing.updatedAt.isAfter(serverUpdatedAt)) break;
        await db.into(db.completions).insertOnConflictUpdate(CompletionsCompanion(
          id: Value(id),
          habitId: Value((r['habit_id'] as num).toInt()),
          day: Value(_msStatic(r['day'])),
          value: Value((r['value'] as num).toDouble()),
          createdAt: Value(_msStatic(r['created_at'])),
          updatedAt: Value(serverUpdatedAt),
          deleted: Value(r['deleted'] as bool? ?? false),
        ));
      case 'vacations':
        await db.into(db.vacations).insertOnConflictUpdate(VacationsCompanion(
          id: Value((r['id'] as num).toInt()),
          userId: const Value(1),
          start: Value(_msStatic(r['start_ts'])),
          end: Value(_msStatic(r['end_ts'])),
          active: Value(r['active'] as bool? ?? false),
          note: Value(r['note'] as String?),
        ));
      case 'habit_schedule_history':
        await db.into(db.habitScheduleHistory).insertOnConflictUpdate(
          HabitScheduleHistoryCompanion(
            id: Value((r['id'] as num).toInt()),
            habitId: Value((r['habit_id'] as num).toInt()),
            effectiveFrom: Value(_msStatic(r['effective_from'])),
            schedule: Value(r['schedule'] as String),
            tracking: Value(r['tracking'] as String),
            createdAt: Value(_msStatic(r['created_at'])),
          ),
        );
      case 'day_shields':
        await db.into(db.dayShields).insertOnConflictUpdate(DayShieldsCompanion(
          id: Value((r['id'] as num).toInt()),
          day: Value(_msStatic(r['day'])),
          appliedAt: Value(r['applied_at'] != null
              ? _msStatic(r['applied_at'])
              : DateTime.now().toUtc()),
        ));
    }
  }

  static Future<void> _deleteLocalRow(AppDatabase db, String table, Map<String, dynamic> r) async {
    switch (table) {
      case 'groups':
        final id = r['id'] as String;
        await (db.delete(db.groups)..where((g) => g.id.equals(id))).go();
      case 'habits':
        final id = (r['id'] as num).toInt();
        await (db.delete(db.habits)..where((h) => h.id.equals(id))).go();
      case 'completions':
        final id = (r['id'] as num).toInt();
        await (db.delete(db.completions)..where((c) => c.id.equals(id))).go();
      case 'vacations':
        final id = (r['id'] as num).toInt();
        await (db.delete(db.vacations)..where((v) => v.id.equals(id))).go();
      case 'habit_schedule_history':
        final id = (r['id'] as num).toInt();
        await (db.delete(db.habitScheduleHistory)..where((h) => h.id.equals(id))).go();
      case 'day_shields':
        final id = (r['id'] as num).toInt();
        await (db.delete(db.dayShields)..where((s) => s.id.equals(id))).go();
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  Future<Set<int>> _serverIntIds(String table) async {
    final rows = await _c.from(table).select('id').eq('user_id', _uid) as List<dynamic>;
    return rows.map((r) => (r['id'] as num).toInt()).toSet();
  }

  /// Returns {id → updatedAt} for habits. Used for LWW conflict resolution.
  Future<Map<int, DateTime>> _serverHabitTimestamps() async {
    final rows = await _c.from('habits').select('id, updated_at, created_at').eq('user_id', _uid) as List<dynamic>;
    return {
      for (final r in rows)
        (r['id'] as num).toInt(): r['updated_at'] != null
            ? _ms(r['updated_at'])
            : _ms(r['created_at']),
    };
  }

  /// Returns {id → updatedAt} for groups. Used for LWW conflict resolution.
  Future<Map<String, DateTime>> _serverGroupTimestamps() async {
    final rows = await _c.from('groups').select('id, updated_at').eq('user_id', _uid) as List<dynamic>;
    return {
      for (final r in rows)
        r['id'] as String: _safeUpdatedAt(r['updated_at']),
    };
  }

  /// Returns {id → updatedAt} for completions. Used for LWW conflict resolution.
  Future<Map<int, DateTime>> _serverCompletionTimestamps() async {
    final rows = await _c.from('completions').select('id, updated_at, created_at').eq('user_id', _uid) as List<dynamic>;
    return {
      for (final r in rows)
        (r['id'] as num).toInt(): r['updated_at'] != null
            ? _ms(r['updated_at'])
            : _ms(r['created_at']),
    };
  }

  DateTime _ms(dynamic ms) =>
      DateTime.fromMillisecondsSinceEpoch((ms as num).toInt(), isUtc: true);

  static DateTime _msStatic(dynamic ms) =>
      DateTime.fromMillisecondsSinceEpoch((ms as num).toInt(), isUtc: true);

  // Clamp the year-58000 corruption from an earlier groups-migration bug.
  // Anything past year ~3000 (32503680000000 ms) is treated as epoch so LWW
  // resyncs cleanly once the bug is fixed on the writer side.
  static const _kBogusUpdatedAtMs = 32503680000000;

  DateTime _safeUpdatedAt(dynamic ms) {
    if (ms == null) {
      return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    }
    final v = (ms as num).toInt();
    if (v > _kBogusUpdatedAtMs) {
      return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    }
    return DateTime.fromMillisecondsSinceEpoch(v, isUtc: true);
  }

  static DateTime _safeUpdatedAtStatic(dynamic ms) {
    if (ms == null) {
      return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    }
    final v = (ms as num).toInt();
    if (v > _kBogusUpdatedAtMs) {
      return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    }
    return DateTime.fromMillisecondsSinceEpoch(v, isUtc: true);
  }
}
