import '../data/database.dart';
import 'schedule.dart';

// Returns the most recent history entry with effective_from <= [dayUtc].
// Ties (same effective_from) are broken by id descending (latest insert wins).
// Order-independent: does not require the list to be pre-sorted.
HabitScheduleHistoryData? effectiveScheduleAt(
    List<HabitScheduleHistoryData> history, DateTime dayUtc) {
  HabitScheduleHistoryData? best;
  for (final h in history) {
    if (h.effectiveFrom.toUtc().isAfter(dayUtc)) continue;
    if (best == null) {
      best = h;
      continue;
    }
    final hFrom = h.effectiveFrom.toUtc();
    final bFrom = best.effectiveFrom.toUtc();
    if (hFrom.isAfter(bFrom) || (hFrom == bFrom && h.id > best.id)) {
      best = h;
    }
  }
  return best;
}

/// Result of the streak computation for one habit or the overall day streak.
///
/// [current]     Actual streak through today (0 if today is due and missed).
/// [pending]     Streak through yesterday — shown in a gray style while today
///               is still at risk (due but not yet completed).
/// [todayAtRisk] True when today is a due day that has no completion yet.
/// [longest]     Longest consecutive streak ever.
/// [shields]     Placeholder — always 0 until Phase 8 ships the shield pool.
class StreakResult {
  final int current;
  final int pending;
  final int longest;
  final int shields;
  final bool todayAtRisk;

  const StreakResult({
    required this.current,
    required this.pending,
    required this.longest,
    required this.shields,
    required this.todayAtRisk,
  });

  // What the UI should display: pending (gray) while at risk, current otherwise.
  int get displayStreak => todayAtRisk ? pending : current;
}

// Returns the UTC instant of local midnight for [localDay].
DateTime localMidnightUtc(DateTime localDay) =>
    DateTime(localDay.year, localDay.month, localDay.day).toUtc();

DateTime _prevDayUtc(DateTime utcDay) {
  final local = utcDay.toLocal();
  return DateTime(local.year, local.month, local.day - 1).toUtc();
}

// Advance a UTC local-midnight by exactly one calendar day (DST-safe).
DateTime _nextDayUtc(DateTime utcDay) {
  final local = utcDay.toLocal();
  return DateTime(local.year, local.month, local.day + 1).toUtc();
}

// ── Per-habit streak ─────────────────────────────────────────────────────────

// Computes streaks for [habit].
//
// The walk is split at "yesterday" so we can return two values:
//   current  = streak through today (0 if today is due but not done).
//   pending  = streak through yesterday (displayed in gray while today is open).
//
// todayAtRisk is true when today is a due day with no completion — the UI
// should show [pending] in a dim color instead of showing 0.
StreakResult computeStreaks(
  Habit habit,
  List<Completion> completions,
  DateTime today,
  List<Vacation> vacations,
  List<HabitScheduleHistoryData> history,
) {
  final completedDays = _buildCompletedDaySet(habit, completions);
  final vacationDays = _buildVacationDaySet(vacations);

  final todayLocal = today.toLocal();
  final todayUtc = localMidnightUtc(todayLocal);
  final yesterdayUtc = _prevDayUtc(todayUtc);

  final startDateDay = localMidnightUtc(habit.startDate.toLocal());
  final endDateUtc = habit.endDate != null
      ? localMidnightUtc(habit.endDate!.toLocal())
      : null;
  // Walk stops at end_date when set, so historic streaks are frozen.
  final walkTo = (endDateUtc != null && endDateUtc.isBefore(todayUtc))
      ? endDateUtc
      : todayUtc;

  var startDay = startDateDay;
  for (final c in completedDays) {
    if (c.isBefore(startDay)) startDay = c;
  }

  var current = 0;
  var longest = 0;

  void advance(DateTime d) {
    if (vacationDays.contains(d)) {
      if (current > 0) {
        current++;
        if (current > longest) longest = current;
      }
      return;
    }
    final entry = effectiveScheduleAt(history, d);
    final schedule = entry?.schedule ?? habit.schedule;
    if (!isDueOnSchedule(schedule, d.toLocal())) return;
    if (completedDays.contains(d)) {
      current++;
      if (current > longest) longest = current;
    } else {
      current = 0;
    }
  }

  // Phase 1: walk through yesterday (or earlier if the habit has ended).
  final phase1End = walkTo.isBefore(yesterdayUtc) ? walkTo : yesterdayUtc;
  var d = startDay;
  while (!d.isAfter(phase1End)) {
    advance(d);
    d = _nextDayUtc(d);
  }
  final pendingCurrent = current;

  // Phase 2: walk today if it's within the habit's active window.
  if (!walkTo.isBefore(todayUtc)) {
    advance(todayUtc);
  }

  // todayAtRisk: today is within range, is a due day, not on vacation, not done.
  var todayAtRisk = false;
  if (!walkTo.isBefore(todayUtc) && !vacationDays.contains(todayUtc)) {
    final entry = effectiveScheduleAt(history, todayUtc);
    final schedule = entry?.schedule ?? habit.schedule;
    todayAtRisk =
        isDueOnSchedule(schedule, todayLocal) && !completedDays.contains(todayUtc);
  }

  return StreakResult(
    current: current,
    pending: pendingCurrent,
    longest: longest,
    shields: 0, // Phase 8 replaces this with the available-shield pool
    todayAtRisk: todayAtRisk,
  );
}

// ── Overall day-wise streak ──────────────────────────────────────────────────

// Computes a day-wise streak: consecutive days where EVERY due habit was
// completed. Used for the top-level header (replaces maxCurrentStreak).
//
// A day is successful when all due habits are done.
// A day is neutral (no effect) when no habits are due.
// Vacation days are neutral (ignored, per spec).
//
// [today] is wall-clock time; the walk is capped at 90 days to match the
// completions window held in memory by [completionMap].
StreakResult computeOverallStreak(
  List<Habit> habits,
  Map<int, List<Completion>> completionMap,
  List<Vacation> vacations,
  Map<int, List<HabitScheduleHistoryData>> historyMap,
  DateTime today,
) {
  if (habits.isEmpty) {
    return const StreakResult(
        current: 0, pending: 0, longest: 0, shields: 0, todayAtRisk: false);
  }

  final todayLocal = today.toLocal();
  final todayUtc = localMidnightUtc(todayLocal);
  final yesterdayUtc = _prevDayUtc(todayUtc);

  // Cap walk start at 90 days to match the recentCompletionsProvider window.
  final cutoff = localMidnightUtc(
      DateTime.now().subtract(const Duration(days: 90)).toLocal());
  DateTime startDay = todayUtc;
  for (final h in habits) {
    final s = localMidnightUtc(h.startDate.toLocal());
    if (s.isBefore(startDay)) startDay = s;
  }
  if (startDay.isBefore(cutoff)) startDay = cutoff;

  final completedDaysMap = {
    for (final h in habits)
      h.id: _buildCompletedDaySet(h, completionMap[h.id] ?? const []),
  };
  final vacationDays = _buildVacationDaySet(vacations);

  // Returns: 1 = all done, 0 = none due (neutral), -1 = at least one missed.
  int dayOutcome(DateTime d) {
    if (vacationDays.contains(d)) return 0; // neutral per spec
    var dueCount = 0;
    var doneCount = 0;
    for (final h in habits) {
      final hStart = localMidnightUtc(h.startDate.toLocal());
      if (d.isBefore(hStart)) continue;
      if (h.endDate != null &&
          d.isAfter(localMidnightUtc(h.endDate!.toLocal()))) continue;
      final entry = effectiveScheduleAt(historyMap[h.id] ?? const [], d);
      final schedule = entry?.schedule ?? h.schedule;
      if (!isDueOnSchedule(schedule, d.toLocal())) continue;
      dueCount++;
      if (completedDaysMap[h.id]!.contains(d)) doneCount++;
    }
    if (dueCount == 0) return 0;
    return doneCount == dueCount ? 1 : -1;
  }

  var current = 0;
  var longest = 0;

  void advance(DateTime d) {
    final outcome = dayOutcome(d);
    if (outcome == 1) {
      current++;
      if (current > longest) longest = current;
    } else if (outcome == -1) {
      current = 0;
    }
    // outcome == 0: neutral day, no change
  }

  var d = startDay;
  while (!d.isAfter(yesterdayUtc)) {
    advance(d);
    d = _nextDayUtc(d);
  }
  final pendingCurrent = current;

  advance(todayUtc);

  final todayAtRisk = dayOutcome(todayUtc) == -1;

  return StreakResult(
    current: current,
    pending: pendingCurrent,
    longest: longest,
    shields: 0, // Phase 8 replaces with available-shield pool
    todayAtRisk: todayAtRisk,
  );
}

// ── helpers ──────────────────────────────────────────────────────────────────

Set<DateTime> _buildCompletedDaySet(
    Habit habit, List<Completion> completions) {
  final double threshold;
  if (habit.tracking == 'checkbox' || habit.tracking == 'health') {
    threshold = 0.5;
  } else {
    threshold = (habit.target ?? 1).toDouble();
  }
  return {
    for (final c in completions)
      if (c.value >= threshold) c.day.toUtc(),
  };
}

Set<DateTime> _buildVacationDaySet(List<Vacation> vacations) {
  final days = <DateTime>{};
  for (final v in vacations) {
    var d = localMidnightUtc(v.start.toLocal());
    final end = localMidnightUtc(v.end.toLocal());
    while (!d.isAfter(end)) {
      days.add(d);
      d = _nextDayUtc(d);
    }
  }
  return days;
}
