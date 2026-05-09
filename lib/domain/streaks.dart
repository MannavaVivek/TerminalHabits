import '../data/database.dart';
import 'schedule.dart';

// Returns the most recent history entry with effective_from <= [dayUtc],
// or null if [history] is empty or all entries are after [dayUtc].
// [history] must be sorted descending by effective_from.
HabitScheduleHistoryData? effectiveScheduleAt(
    List<HabitScheduleHistoryData> history, DateTime dayUtc) {
  for (final h in history) {
    if (!h.effectiveFrom.toUtc().isAfter(dayUtc)) return h;
  }
  return null;
}

/// Result of the streak computation for one habit.
class StreakResult {
  final int current;
  final int longest;
  final int shields;
  const StreakResult({
    required this.current,
    required this.longest,
    required this.shields,
  });
}

// Returns the UTC instant of local midnight for [localDay].
DateTime localMidnightUtc(DateTime localDay) =>
    DateTime(localDay.year, localDay.month, localDay.day).toUtc();

// Computes streaks for [habit].
//
// Algorithm:
//  1. Walk every calendar day from min(createdAt, oldest completion) → today.
//  2. For each day:
//       - vacation day: extends an active streak silently (no break).
//       - non-due day: skipped (no effect on streak).
//       - due day completed: streak += 1.
//       - due day missed: streak resets to 0.
//  3. Track the running max as `longest`.
//  4. `shields` = floor(longest / 7). Purely a milestone counter; no
//     auto-absorption of misses (that turned out to be flaky and was the
//     source of the "streak doesn't update on uncheck" bug).
StreakResult computeStreaks(
  Habit habit,
  List<Completion> completions,
  DateTime today,
  List<Vacation> vacations,
  List<HabitScheduleHistoryData> history,
) {
  final completedDays = _buildCompletedDaySet(habit, completions);
  final vacationDays = _buildVacationDaySet(vacations);

  final startDateDay = localMidnightUtc(habit.startDate.toLocal());
  final todayUtc = localMidnightUtc(today.toLocal());

  // Walk stops at end_date when set, so historic streaks are frozen.
  final endDateUtc = habit.endDate != null
      ? localMidnightUtc(habit.endDate!.toLocal())
      : null;
  final walkTo =
      endDateUtc != null && endDateUtc.isBefore(todayUtc) ? endDateUtc : todayUtc;

  // Walk from the earliest of (start_date, oldest backfilled completion).
  var startDay = startDateDay;
  for (final d in completedDays) {
    if (d.isBefore(startDay)) startDay = d;
  }

  var current = 0;
  var longest = 0;
  var d = startDay;

  while (!d.isAfter(walkTo)) {
    if (vacationDays.contains(d)) {
      if (current > 0) {
        current++;
        if (current > longest) longest = current;
      }
      d = _nextDayUtc(d);
      continue;
    }
    // Use the schedule that was effective on day [d].
    final entry = effectiveScheduleAt(history, d);
    final schedule = entry?.schedule ?? habit.schedule;
    if (!isDueOnSchedule(schedule, d.toLocal())) {
      d = _nextDayUtc(d);
      continue;
    }

    if (completedDays.contains(d)) {
      current++;
      if (current > longest) longest = current;
    } else {
      current = 0;
    }
    d = _nextDayUtc(d);
  }

  final shields = longest ~/ 7;
  return StreakResult(current: current, longest: longest, shields: shields);
}

// ── helpers ─────────────────────────────────────────────────────────────────

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

// Advance a UTC local-midnight by exactly one calendar day (DST-safe).
DateTime _nextDayUtc(DateTime utcDay) {
  final local = utcDay.toLocal();
  return DateTime(local.year, local.month, local.day + 1).toUtc();
}
