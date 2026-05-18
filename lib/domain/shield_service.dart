import '../data/database.dart';
import '../domain/schedule.dart';
import '../domain/streaks.dart';

/// Runs the once-per-launch shield scan.
///
/// Pass 1 — spending: walks [last_seen_date+1 … yesterday] chronologically.
/// Shields are only spent on days on or after the latest habit createdAt, so
/// backdated history never triggers spending.  A miss is only shielded when
/// the overall streak is alive at that point.
///
/// Pass 2 — earning: calls [recomputeShieldPool] so the pool reflects
/// every milestone crossed in the full streak history.
///
/// Sets last_seen_date = yesterday so the next launch picks up from today.
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
  // Run before the spending pass so the pool count is correct.
  final allShields = await db.getAllDayShields();
  var shields = await db.getAvailableShields();
  for (final shield in allShields) {
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
  // Only spend shields already in the pool before this scan.
  //
  // Two guards before a shield is spent on day D:
  //   1. The overall streak must be alive (spendingStreak > 0).
  //   2. D must be on or after every habit's createdAt — backdated history
  //      earns milestones but never consumes shields.
  final shieldRows = await db.getAllDayShields();
  final shieldedDays = {for (final s in shieldRows) s.day.toUtc()};
  final vacationDays = buildVacationDaySet(vacations);
  shields = await db.getAvailableShields();

  // Earliest day on which spending is allowed = latest createdAt across habits.
  DateTime spendingStart = DateTime(1970);
  for (final h in habits) {
    final c = h.createdAt.toLocal();
    final cDay = DateTime(c.year, c.month, c.day);
    if (cDay.isAfter(spendingStart)) spendingStart = cDay;
  }

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
        if (spendingStreak > 0 && shields > 0 && !d.isBefore(spendingStart)) {
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
/// Also runs auto-recovery: if a shielded day is now fully complete (the user
/// went back and filled it in), the shield row is removed so it no longer
/// counts as spent. This is the session-time recovery path — the launch scan
/// handles the at-startup case.
///
/// Safe to call after every completion write/delete during a session.
Future<void> recomputeShieldPool({
  required AppDatabase db,
  required List<Habit> habits,
  required Map<int, List<Completion>> completionMap,
  required List<Vacation> vacations,
  required Map<int, List<HabitScheduleHistoryData>> historyMap,
}) async {
  if (habits.isEmpty) return;

  // Auto-recovery: remove shields for days that are now fully complete.
  final allShields = await db.getAllDayShields();
  for (final shield in allShields) {
    if (_dayFullyComplete(shield.day.toUtc(), habits, completionMap, historyMap)) {
      await db.deleteDayShield(shield.day);
    }
  }

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
/// Iterates LOCAL calendar days so the walk is correct in every timezone.
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
  return _dayOutcome(d, localMidnightUtc(d), habits, completionMap, historyMap) == 1;
}

String _isoDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
