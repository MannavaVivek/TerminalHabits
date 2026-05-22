import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint;
import '../data/database.dart';
import 'health_service.dart';

/// Reads today's value from Health Connect for every `tracking='health'`
/// habit, and toggles the completion accordingly:
///   - value >= target → ensure a completion exists for today
///   - value <  target → soft-delete any existing completion for today
///
/// Runs on app open and after pull-to-refresh on Android. No-op elsewhere.
Future<void> runHealthSync(AppDatabase db, List<Habit> habits) async {
  if (!Platform.isAndroid) return;

  final healthHabits = habits
      .where((h) => h.tracking == 'health' &&
          h.healthSource != null &&
          h.target != null &&
          !h.deleted &&
          h.archivedAt == null)
      .toList();
  if (healthHabits.isEmpty) return;

  final now = DateTime.now();
  final todayUtc =
      DateTime.utc(now.year, now.month, now.day);

  // Cache reads per source so multiple habits using the same source
  // (e.g. two step-goal habits) only hit Health Connect once.
  final cache = <String, int?>{};

  for (final h in healthHabits) {
    final source = h.healthSource!;
    int? value;
    if (cache.containsKey(source)) {
      value = cache[source];
    } else {
      value = await HealthService.readTodayValue(source);
      cache[source] = value;
    }
    if (value == null) continue;

    final target = h.target!;
    if (value >= target) {
      // Goal met — ensure completion exists.
      await db.setCompletionValue(h.id, todayUtc, value.toDouble());
      debugPrint('health: ${h.name} goal met ($value/$target)');
    } else {
      // Below goal — remove any prior auto-completion.
      await db.softDeleteCompletionIfPresent(h.id, todayUtc);
    }
  }
}
