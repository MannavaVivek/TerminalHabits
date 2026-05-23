import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint;
import '../data/database.dart';
import 'health_service.dart';
import 'streaks.dart' show localMidnightUtc;

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

  // Match the rest of the app: a completion's `day` is local midnight
  // expressed in UTC, not DateTime.utc(y,m,d). Those only coincide at UTC+0.
  final todayUtc = localMidnightUtc(DateTime.now());

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
    if (value == null) {
      // Either Health Connect denied us, hasn't synced, or the read failed.
      // Leave any existing completion alone — don't clobber prior progress.
      continue;
    }
    if (value <= 0) continue; // nothing to record yet today

    final existing = await db.getCompletionForDay(h.id, todayUtc);
    if (existing == null || existing.deleted) {
      // No row, or the user cleared it via the value-input dialog — write
      // the current Health Connect value fresh. Treating a cleared row as
      // "resume auto-tracking" lets the user undo a manual override.
      await db.setCompletionValue(h.id, todayUtc, value.toDouble());
    } else if (value > existing.value) {
      // Existing row is a higher manual entry — only advance, never
      // overwrite a manual override downward.
      await db.setCompletionValue(h.id, todayUtc, value.toDouble());
    }
    debugPrint('health: ${h.name} $value/${h.target}');
  }
}
