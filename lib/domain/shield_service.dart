import '../data/database.dart';
import '../domain/schedule.dart';
import '../domain/streaks.dart';

/// Runs the once-per-launch shield scan.
///
/// Processes days from [last_seen_date + 1] to yesterday (chronological).
/// For each missed day: consumes a shield if available, else locks it as a miss.
/// Also runs auto-recovery: shielded days that are now fully complete return
/// their shield to the pool.
/// Updates [last_seen_date] to today on completion.
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

  // ── Auto-recovery ──────────────────────────────────────────────────────────
  // For every existing shield: if the day is now fully complete, recover it.
  final allShields = await db.getAllDayShields();
  var shields = await db.getAvailableShields();
  for (final shield in allShields) {
    if (_dayFullyComplete(shield.day, habits, completionMap, historyMap)) {
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
    await db.setSetting('last_seen_date', _isoDate(todayLocal));
    return;
  }

  // Reload shields (recovery may have changed them)
  final shieldRows = await db.getAllDayShields();
  final shieldedDays = {for (final s in shieldRows) s.day};
  final vacationDays = buildVacationDaySet(vacations);
  shields = await db.getAvailableShields();
  final interval = int.tryParse(await db.getSetting('shieldEarnInterval') ?? '7') ?? 7;

  // Compute overall streak up to the day before the scan starts.
  // This initialises streakCount and the last-milestone boundary.
  final dayBeforeScan = DateTime(scanFrom.year, scanFrom.month, scanFrom.day - 1);
  final preScan = computeOverallStreak(
      habits, completionMap, vacations, historyMap, dayBeforeScan, shieldedDays);
  var streakCount = preScan.current;
  // lastMilestone = highest interval multiple already <= streakCount.
  var lastMilestone = (streakCount ~/ interval) * interval;

  var d = scanFrom;
  while (!d.isAfter(yesterday)) {
    final dUtc = localMidnightUtc(d);

    if (vacationDays.contains(dUtc)) {
      d = DateTime(d.year, d.month, d.day + 1);
      continue;
    }

    if (shieldedDays.contains(dUtc)) {
      // Already shielded from a prior scan — counts as success.
      streakCount++;
      shields = _checkMilestone(streakCount, interval, lastMilestone, shields);
      lastMilestone = (streakCount ~/ interval) * interval;
      d = DateTime(d.year, d.month, d.day + 1);
      continue;
    }

    final outcome = _dayOutcome(d, dUtc, habits, completionMap, historyMap);

    if (outcome == 1) {
      streakCount++;
      shields = _checkMilestone(streakCount, interval, lastMilestone, shields);
      lastMilestone = (streakCount ~/ interval) * interval;
    } else if (outcome == -1) {
      if (shields > 0) {
        await db.insertDayShield(dUtc);
        shieldedDays.add(dUtc);
        shields--;
        streakCount++;
        shields = _checkMilestone(streakCount, interval, lastMilestone, shields);
        lastMilestone = (streakCount ~/ interval) * interval;
      } else {
        streakCount = 0;
        lastMilestone = 0;
      }
    }
    // outcome 0: neutral — no change to streakCount

    d = DateTime(d.year, d.month, d.day + 1);
  }

  await db.setAvailableShields(shields);
  await db.setSetting('last_seen_date', _isoDate(todayLocal));
}

// ── helpers ───────────────────────────────────────────────────────────────────

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
        (h.tracking == 'checkbox' || h.tracking == 'health') ? 0.5 : (h.target ?? 1).toDouble();
    final comps = completionMap[h.id] ?? const [];
    if (comps.any((c) => c.day.toUtc() == dUtc && c.value >= threshold)) done++;
  }
  if (due == 0) return 0;
  return done == due ? 1 : -1;
}

/// True when every due habit was completed on [dayUtc].
bool _dayFullyComplete(
  DateTime dayUtc,
  List<Habit> habits,
  Map<int, List<Completion>> completionMap,
  Map<int, List<HabitScheduleHistoryData>> historyMap,
) {
  final local = dayUtc.toLocal();
  final d = DateTime(local.year, local.month, local.day);
  return _dayOutcome(d, dayUtc, habits, completionMap, historyMap) == 1;
}

/// Awards milestone shields and returns the updated pool count.
int _checkMilestone(int streak, int interval, int lastMilestone, int shields) {
  final newMilestone = (streak ~/ interval) * interval;
  if (newMilestone > lastMilestone) {
    return shields + (newMilestone - lastMilestone) ~/ interval;
  }
  return shields;
}

String _isoDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
