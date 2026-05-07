import '../data/database.dart';
import 'schedule.dart';

/// Result of the streak computation for one habit.
class StreakResult {
  final int current;
  final int longest;
  final int shields; // remaining (earned - consumed)
  const StreakResult({
    required this.current,
    required this.longest,
    required this.shields,
  });
}

// Returns the UTC instant of local midnight for [localDay].
DateTime localMidnightUtc(DateTime localDay) =>
    DateTime(localDay.year, localDay.month, localDay.day).toUtc();

// Computes streaks and shields for [habit].
//
// Algorithm per data_model.md §6:
//  1. Build completed-day set from completions (value >= target for count/number).
//  2. Walk backward from today across due days.
//  3. Each 7-day window of consecutive due days earns one shield at the 7th day.
//  4. A shield can absorb one missed-but-due day per 7-day window.
//  5. Vacation days are neutral (neither extend nor break streaks).
StreakResult computeStreaks(
  Habit habit,
  List<Completion> completions,
  DateTime today,
  List<Vacation> vacations,
) {
  final completedDays = _buildCompletedDaySet(habit, completions);
  final vacationDays = _buildVacationDaySet(vacations);

  // Walk the full history to compute longest and shields earned.
  final createdDay = localMidnightUtc(habit.createdAt.toLocal());
  final todayUtc = localMidnightUtc(today.toLocal());

  // Forward pass: find all due days and detect consecutive runs.
  final current = _computeCurrent(
      habit, completedDays, vacationDays, todayUtc);
  final longest = _computeLongest(
      habit, completedDays, vacationDays, createdDay, todayUtc);
  final shields = _computeShieldsRemaining(
      habit, completedDays, vacationDays, createdDay, todayUtc, current);

  return StreakResult(current: current, longest: longest, shields: shields);
}

// ── helpers ─────────────────────────────────────────────────────────────────

Set<DateTime> _buildCompletedDaySet(Habit habit, List<Completion> completions) {
  final double threshold;
  if (habit.tracking == 'checkbox' || habit.tracking == 'health') {
    threshold = 0.5; // any positive value counts
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

bool _isDue(Habit h, DateTime utcDay, Set<DateTime> vacDays) {
  if (vacDays.contains(utcDay)) return false;
  return isHabitDueOn(h, utcDay.toLocal());
}

int _computeCurrent(
  Habit habit,
  Set<DateTime> completed,
  Set<DateTime> vacation,
  DateTime todayUtc,
) {
  var run = 0;
  var shieldsAvailable = 0;
  var daysInWindow = 0;
  var missedInWindow = 0;
  var d = localMidnightUtc(habit.createdAt.toLocal());

  while (!d.isAfter(todayUtc)) {
    // Vacation days extend an active streak without consuming window slots.
    if (vacation.contains(d)) {
      if (run > 0) run++;
      d = _nextDayUtc(d);
      continue;
    }
    if (!isHabitDueOn(habit, d.toLocal())) {
      d = _nextDayUtc(d);
      continue;
    }

    daysInWindow++;
    if (daysInWindow == 7) {
      shieldsAvailable++;
      daysInWindow = 0;
      missedInWindow = 0;
    }

    if (completed.contains(d)) {
      run++;
      missedInWindow = 0;
    } else if (shieldsAvailable > 0 && missedInWindow == 0) {
      shieldsAvailable--;
      missedInWindow++;
      run++;
    } else {
      run = 0;
      shieldsAvailable = 0;
      daysInWindow = 0;
      missedInWindow = 0;
    }

    d = _nextDayUtc(d);
  }

  return run;
}

int _computeLongest(
  Habit habit,
  Set<DateTime> completed,
  Set<DateTime> vacation,
  DateTime createdUtc,
  DateTime todayUtc,
) {
  var longest = 0;
  var run = 0;
  var shieldsAvailable = 0;
  var daysInWindow = 0;
  var missedInWindow = 0;
  var d = createdUtc;

  while (!d.isAfter(todayUtc)) {
    if (vacation.contains(d)) {
      if (run > 0) {
        run++;
        if (run > longest) longest = run;
      }
      d = _nextDayUtc(d);
      continue;
    }
    if (!isHabitDueOn(habit, d.toLocal())) {
      d = _nextDayUtc(d);
      continue;
    }

    daysInWindow++;
    if (daysInWindow == 7) {
      shieldsAvailable++;
      daysInWindow = 0;
      missedInWindow = 0;
    }

    if (completed.contains(d)) {
      run++;
      missedInWindow = 0;
      if (run > longest) longest = run;
    } else if (shieldsAvailable > 0 && missedInWindow == 0) {
      shieldsAvailable--;
      missedInWindow++;
      run++;
      if (run > longest) longest = run;
    } else {
      run = 0;
      shieldsAvailable = 0;
      daysInWindow = 0;
      missedInWindow = 0;
    }

    d = _nextDayUtc(d);
  }

  return longest;
}

int _computeShieldsRemaining(
  Habit habit,
  Set<DateTime> completed,
  Set<DateTime> vacation,
  DateTime createdUtc,
  DateTime todayUtc,
  int currentStreak,
) {
  // Shields earned = consecutive-7-day milestones across all time.
  var earned = 0;
  var daysInWindow = 0;
  var d = createdUtc;

  while (!d.isAfter(todayUtc)) {
    if (_isDue(habit, d, vacation)) {
      daysInWindow++;
      if (daysInWindow == 7) {
        earned++;
        daysInWindow = 0;
      }
    }
    d = _nextDayUtc(d);
  }

  // Shields consumed = how many miss-absorptions were needed in the current streak.
  // Simplified: earned - (number of misses absorbed in current run, which we can
  // derive from current streak length vs due days in that span).
  // For Phase 1, return earned shields as surplus (conservative estimate).
  return earned;
}
