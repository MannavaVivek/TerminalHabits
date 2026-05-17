import '../data/database.dart';
import '../domain/schedule.dart';
import '../domain/streaks.dart';

/// Runs the once-per-launch shield scan.
///
/// Pass 1 — spending: walks [last_seen_date+1 … yesterday] chronologically.
/// For each completion-miss, consumes one pre-existing shield (not shields
/// earned in this same scan) and inserts a day_shields row.
///
/// Pass 2 — earning: calls [recomputeShieldPool] so the pool reflects
/// every milestone crossed in the full streak history.
///
/// Sets last_seen_date = yesterday so the next launch picks up from today
/// (today hasn't ended yet and cannot be processed).
Future<void> runLaunchScan({
  required AppDatabase db,
  required List<Habit> habits,
  required Map<int, List<Completion>> completionMap,
  required List<Vacation> vacations,
  required Map<int, List<HabitScheduleHistoryData>> historyMap,
}) async {
  if (habits.isEmpty) return;

  final now = DateTime.now();
  final todayLocal = DateTime(now.year, now.month, now.day);
  final yesterday = DateTime(todayLocal.year, todayLocal.month, todayLocal.day - 1);
  final yesterdayStr = _isoDate(yesterday);

  // ── Auto-recovery ──────────────────────────────────────────────────────────
  final allShields = await db.getAllDayShields();
  var shields = await db.getAvailableShields();
  for (final shield in allShields) {
    // Drift returns local datetimes; normalise to UTC before comparing.
    final dayUtc = shield.day.toUtc();
    if (_dayFullyComplete(dayUtc, habits, completionMap, historyMap)) {
      await db.deleteDayShield(shield.day);
      shields++;
    }
  }
  await db.setAvailableShields(shields);

  // ── Scan range ─────────────────────────────────────────────────────────────
  final lastSeenStr = await db.getSetting('last_seen_date') ?? '';
  DateTime scanFrom;
  if (lastSeenStr.isEmpty) {
    scanFrom = DateTime(todayLocal.year, todayLocal.month, todayLocal.day - 90);
  } else {
    final p = lastSeenStr.split('-');
    final last = DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
    scanFrom = DateTime(last.year, last.month, last.day + 1);
  }

  if (scanFrom.isAfter(yesterday)) {
    await db.setSetting('last_seen_date', yesterdayStr);
    await recomputeShieldPool(
        db: db,
        habits: habits,
        completionMap: completionMap,
        vacations: vacations,
        historyMap: historyMap);
    return;
  }

  // ── Pass 1: SPENDING ───────────────────────────────────────────────────────
  // Spend only shields already in the pool before this scan. Milestones earned
  // during this scan (pass 2 below) are banked, not consumed here.
  //
  // Shields are only consumed while the overall streak is alive — a miss on an
  // already-broken streak should not burn a shield.
  final shieldRows = await db.getAllDayShields();
  // Drift returns local datetimes; normalise to UTC so Set.contains() works.
  final shieldedDays = {for (final s in shieldRows) s.day.toUtc()};
  final vacationDays = buildVacationDaySet(vacations);
  shields = await db.getAvailableShields();

  // Streak value at the end of the day before scanFrom.
  final preScan = computeOverallStreak(
      habits, completionMap, vacations, historyMap, scanFrom, shieldedDays);
  var spendingStreak = preScan.pending;

  var d = scanFrom;
  while (!d.isAfter(yesterday)) {
    final dUtc = localMidnightUtc(d);
    if (vacationDays.contains(dUtc)) {
      // neutral day — streak unaffected
    } else if (shieldedDays.contains(dUtc)) {
      // already shielded from a prior scan — counts as a success
      spendingStreak++;
    } else {
      final outcome = _dayOutcome(d, dUtc, habits, completionMap, historyMap);
      if (outcome == 1) {
        spendingStreak++;
      } else if (outcome == -1) {
        if (spendingStreak > 0 && shields > 0) {
          await db.insertDayShield(dUtc);
          shieldedDays.add(dUtc);
          shields--;
          spendingStreak++; // shielded miss keeps the streak alive
        } else {
          spendingStreak = 0;
        }
      }
      // outcome == 0 (no habits due): neutral, streak unchanged
    }
    d = DateTime(d.year, d.month, d.day + 1);
  }
  await db.setAvailableShields(shields);

  await db.setSetting('last_seen_date', yesterdayStr);

  // ── Pass 2: EARNING ────────────────────────────────────────────────────────
  await recomputeShieldPool(
      db: db,
      habits: habits,
      completionMap: completionMap,
      vacations: vacations,
      historyMap: historyMap);
}

/// Recomputes available_shields = totalMilestonesEarned − shieldedDaysCount.
///
/// This is deterministic given the current completion and shield state, so it
/// is safe to call after every completion write/delete during a session.
/// Calling it reactively keeps the pool accurate without re-running the full
/// spending pass.
Future<void> recomputeShieldPool({
  required AppDatabase db,
  required List<Habit> habits,
  required Map<int, List<Completion>> completionMap,
  required List<Vacation> vacations,
  required Map<int, List<HabitScheduleHistoryData>> historyMap,
}) async {
  if (habits.isEmpty) return;

  final shieldRows = await db.getAllDayShields();
  final shieldedDays = {for (final s in shieldRows) s.day.toUtc()};
  final interval =
      int.tryParse(await db.getSetting('shieldEarnInterval') ?? '7') ?? 7;

  final now = DateTime.now();
  final todayLocal = DateTime(now.year, now.month, now.day);

  final totalEarned = _totalMilestonesEarned(
      habits, completionMap, vacations, historyMap,
      todayLocal, shieldedDays, interval);

  final pool = (totalEarned - shieldedDays.length).clamp(0, 999);
  await db.setAvailableShields(pool);
}

// ── helpers ───────────────────────────────────────────────────────────────────

/// Walks all days from the earliest habit start (capped at 90 days) through
/// yesterday, counting every milestone crossing across all streak runs.
/// Each streak break resets the per-run milestone boundary, so a fresh run
/// can earn milestones independently.
///
/// Iterates LOCAL calendar days (same pattern as runLaunchScan) so the walk
/// is correct in every timezone, including non-UTC offsets and DST gaps.
int _totalMilestonesEarned(
  List<Habit> habits,
  Map<int, List<Completion>> completionMap,
  List<Vacation> vacations,
  Map<int, List<HabitScheduleHistoryData>> historyMap,
  DateTime todayLocal,
  Set<DateTime> shieldedDays,
  int interval,
) {
  if (interval <= 0) return 0;

  // All dates kept as LOCAL midnight; UTC conversion only for DB lookups.
  final yesterday =
      DateTime(todayLocal.year, todayLocal.month, todayLocal.day - 1);
  final cutoff =
      DateTime(todayLocal.year, todayLocal.month, todayLocal.day - 90);

  DateTime startLocal = todayLocal;
  for (final h in habits) {
    final s = h.startDate.toLocal();
    final sDay = DateTime(s.year, s.month, s.day);
    if (sDay.isBefore(startLocal)) startLocal = sDay;
  }
  if (startLocal.isBefore(cutoff)) startLocal = cutoff;

  final vacationDays = buildVacationDaySet(vacations);

  var streak = 0;
  var lastMilestone = 0;
  var totalEarned = 0;

  var d = startLocal;
  while (!d.isAfter(yesterday)) {
    final dUtc = localMidnightUtc(d);

    if (vacationDays.contains(dUtc)) {
      d = DateTime(d.year, d.month, d.day + 1);
      continue;
    }

    final int outcome;
    if (shieldedDays.contains(dUtc)) {
      outcome = 1;
    } else {
      outcome = _dayOutcome(d, dUtc, habits, completionMap, historyMap);
    }

    if (outcome == 1) {
      streak++;
      final newMilestone = (streak ~/ interval) * interval;
      if (newMilestone > lastMilestone) {
        totalEarned += (newMilestone - lastMilestone) ~/ interval;
        lastMilestone = newMilestone;
      }
    } else if (outcome == -1) {
      streak = 0;
      lastMilestone = 0;
    }

    d = DateTime(d.year, d.month, d.day + 1);
  }

  return totalEarned;
}

/// Returns 1 (all done), 0 (none due / neutral), or -1 (at least one missed).
int _dayOutcome(
  DateTime d,
  DateTime dUtc,
  List<Habit> habits,
  Map<int, List<Completion>> completionMap,
  Map<int, List<HabitScheduleHistoryData>> historyMap,
) {
  var due = 0;
  var done = 0;
  for (final h in habits) {
    final hStart = localMidnightUtc(h.startDate.toLocal());
    if (dUtc.isBefore(hStart)) continue;
    if (h.endDate != null &&
        dUtc.isAfter(localMidnightUtc(h.endDate!.toLocal()))) continue;
    final entry = effectiveScheduleAt(historyMap[h.id] ?? const [], dUtc);
    final schedule = entry?.schedule ?? h.schedule;
    if (!isDueOnSchedule(schedule, d)) continue;
    due++;
    final threshold =
        (h.tracking == 'checkbox' || h.tracking == 'health')
            ? 0.5
            : (h.target ?? 1).toDouble();
    final comps = completionMap[h.id] ?? const [];
    if (comps.any((c) => c.day.toUtc() == dUtc && c.value >= threshold)) done++;
  }
  if (due == 0) return 0;
  return done == due ? 1 : -1;
}

/// True when every due habit was completed on [dayUtc].
/// [dayUtc] must be a UTC instant (local midnight expressed in UTC).
bool _dayFullyComplete(
  DateTime dayUtc,
  List<Habit> habits,
  Map<int, List<Completion>> completionMap,
  Map<int, List<HabitScheduleHistoryData>> historyMap,
) {
  final local = dayUtc.toLocal();
  final d = DateTime(local.year, local.month, local.day);
  // Re-derive UTC via localMidnightUtc so the value is always isUtc=true,
  // which is required for the c.day.toUtc() == dUtc comparison in _dayOutcome.
  return _dayOutcome(d, localMidnightUtc(d), habits, completionMap, historyMap) == 1;
}

String _isoDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
