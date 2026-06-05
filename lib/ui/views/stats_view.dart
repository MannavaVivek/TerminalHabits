import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database.dart';
import '../../domain/schedule.dart';
import '../../domain/streaks.dart';
import '../../state/providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/tokens.dart';
import '../widgets/contribution_grid.dart';
import '../widgets/prompt_line.dart';

const _periods = [7, 30, 90, 365, -1];
const _periodLabels = ['7d', '30d', '90d', '365d', 'all'];

class StatsView extends ConsumerStatefulWidget {
  const StatsView({super.key});

  @override
  ConsumerState<StatsView> createState() => _StatsViewState();
}

class _StatsViewState extends ConsumerState<StatsView> {
  int _periodIdx = 0; // 7d default

  @override
  Widget build(BuildContext context) {
    final col = context.col;
    final userName = ref.watch(userNameProvider);
    final habitsAV = ref.watch(habitsProvider);
    final yearlyAV = ref.watch(yearlyCompletionsProvider);
    final vacAV = ref.watch(vacationsProvider);
    final historyAV = ref.watch(scheduleHistoryProvider);
    final dailyAV = ref.watch(dailyStateProvider);

    final shieldsAV = ref.watch(dayShieldsProvider);
    final loading = habitsAV.isLoading || yearlyAV.isLoading || vacAV.isLoading;

    final sinceUtc = localMidnightUtc(DateTime.now().subtract(const Duration(days: 365)).toLocal());
    final shieldSet = shieldsAV.valueOrNull ?? const {};
    final shieldedDaysCount = shieldSet.where((d) => !d.isBefore(sinceUtc)).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(TH.s14),
          child: PromptLine(user: userName, command: 'stats'),
        ),
        if (loading)
          const Expanded(child: SizedBox.shrink())
        else
          Expanded(
            child: _StatsBody(
              habits: habitsAV.valueOrNull ?? const [],
              yearlyMap: yearlyAV.valueOrNull ?? const {},
              vacations: vacAV.valueOrNull ?? const [],
              historyMap: historyAV.valueOrNull ?? const {},
              overallStreak: dailyAV.valueOrNull?.overallStreak,
              col: col,
              periodIdx: _periodIdx,
              onPeriodChanged: (i) => setState(() => _periodIdx = i),
              shieldedDaysCount: shieldedDaysCount,
            ),
          ),
      ],
    );
  }
}

class _StatsBody extends StatelessWidget {
  final List<Habit> habits;
  final Map<int, List<Completion>> yearlyMap;
  final List<Vacation> vacations;
  final Map<int, List<HabitScheduleHistoryData>> historyMap;
  final StreakResult? overallStreak;
  final AppColors col;
  final int periodIdx;
  final ValueChanged<int> onPeriodChanged;
  final int shieldedDaysCount;

  const _StatsBody({
    required this.habits,
    required this.yearlyMap,
    required this.vacations,
    required this.historyMap,
    required this.overallStreak,
    required this.col,
    required this.periodIdx,
    required this.onPeriodChanged,
    required this.shieldedDaysCount,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final days = _periods[periodIdx];
    final label = _periodLabels[periodIdx];

    // Per-habit streaks using 365-day completions.
    final allStreaks = <int, StreakResult>{
      for (final h in habits)
        h.id: computeStreaks(
          h, yearlyMap[h.id] ?? const [], now, vacations,
          historyMap[h.id] ?? const [],
        ),
    };

    // ── Lifetime overview ────────────────────────────────────────────────────
    final glance = _computeQuickGlance(now, shieldedDaysCount);

    // ── Streaks ──────────────────────────────────────────────────────────────
    final currentStreak = overallStreak?.displayStreak ?? 0;
    final bestStreak = overallStreak?.longest ?? 0;
    Habit? topHabit;
    var topHabitStreak = 0;
    for (final h in habits) {
      final s = allStreaks[h.id]?.current ?? 0;
      if (s > topHabitStreak) {
        topHabitStreak = s;
        topHabit = h;
      }
    }

    // ── Completion rates ─────────────────────────────────────────────────────
    final ratesData = _computeRatesData(now, days, offsetDays: 0);
    final prevData = days > 0
        ? _computeRatesData(now, days, offsetDays: days)
        : null;
    final delta =
        prevData != null ? ratesData.rate - prevData.rate : null;

    // ── Contributions ────────────────────────────────────────────────────────
    // Only count completions whose habit is still active — yearlyMap can
    // include orphan completions from archived/deleted habits.
    final activeHabitIds = {for (final h in habits) h.id};
    final Map<DateTime, int> completionsByDay = {};
    for (final entry in yearlyMap.entries) {
      if (!activeHabitIds.contains(entry.key)) continue;
      for (final c in entry.value) {
        final day = DateTime(c.day.toLocal().year, c.day.toLocal().month,
            c.day.toLocal().day);
        completionsByDay[day] = (completionsByDay[day] ?? 0) + 1;
      }
    }

    // ── Day of week ──────────────────────────────────────────────────────────
    final dowResult = _computeDowRates(now, days);
    final dowRates = dowResult.rates;
    const dowLabels = ['mo', 'tu', 'we', 'th', 'fr', 'sa', 'su'];
    int? bestDow, worstDow;
    double bestRate = -1, worstRate = 2;
    for (var i = 0; i < 7; i++) {
      if (dowResult.dueCounts[i] > 0) {
        if (dowRates[i] > bestRate) {
          bestRate = dowRates[i];
          bestDow = i;
        }
        if (dowRates[i] < worstRate) {
          worstRate = dowRates[i];
          worstDow = i;
        }
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(TH.s14, 0, TH.s14, TH.s22),
      children: [
        // 1. Lifetime overview
        _StatBlock(
          label: 'lifetime overview',
          comment: '// your overall tracking summary',
          col: col,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _KV('days tracked', '${glance.daysTracked} days', col: col),
              _KV('avg completion',
                  '${(glance.avgCompletion * 100).round()}%', col: col),
              _KV('total completions', '${glance.totalCompletions}',
                  col: col),
            ],
          ),
        ),
        const SizedBox(height: TH.s8),

        // 2. Streaks
        _StatBlock(
          label: 'streaks',
          comment: '// consecutive days hitting your daily goal',
          col: col,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _KV('current streak', '$currentStreak days', col: col),
              _KV('best streak', '$bestStreak days', col: col),
              if (topHabit != null)
                _KV('top habit streak',
                    '${topHabit.name} — $topHabitStreak days',
                    col: col),
            ],
          ),
        ),
        const SizedBox(height: TH.s8),

        // 3. Data window (shared period picker)
        _StatBlock(
          label: 'data window',
          comment: '// choose from presets, or select a range',
          col: col,
          child: _PeriodPicker(
            selectedIdx: periodIdx,
            col: col,
            onChanged: onPeriodChanged,
          ),
        ),
        const SizedBox(height: TH.s8),

        // 4. Completion rates
        _StatBlock(
          label: 'completion rates [$label]',
          comment: '// how often you complete scheduled habits',
          col: col,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _KV('this $label', _fmtRate(ratesData.rate, delta), col: col),
              if (prevData != null)
                _KV('previous $label',
                    '${(prevData.rate * 100).round()}%', col: col),
              _KV('perfect days',
                  '${ratesData.greenDays}/${days < 0 ? ratesData.trackedDays : days}',
                  col: col),
              _KV('shielded days', '${glance.shieldedDays}', col: col),
            ],
          ),
        ),
        const SizedBox(height: TH.s8),

        // 5. Day of week
        _StatBlock(
          label: 'day of week [$label]',
          comment: '// completion rates broken down by day',
          col: col,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < 7; i++)
                _BarRow(
                  label: dowLabels[i],
                  value: dowRates[i],
                  col: col,
                ),
              if (bestDow != null && worstDow != null &&
                  bestDow != worstDow) ...[
                const SizedBox(height: TH.s4),
                Text(
                  'best day: ${dowLabels[bestDow]} '
                  '(${(bestRate * 100).round()}%)',
                  style: TextStyle(color: col.green, fontSize: 11),
                ),
                Text(
                  'worst day: ${dowLabels[worstDow]} '
                  '(${(worstRate * 100).round()}%)',
                  style: TextStyle(color: col.fgMute, fontSize: 11),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: TH.s8),

        // 6. Contributions (yearly heatmap — always last)
        _StatBlock(
          label: 'contributions',
          comment: '// your activity over the past year',
          col: col,
          child: ContributionGrid(
            completionsByDay: completionsByDay,
            col: col,
            summary: _ContribSummary(
              daysTracked: glance.daysTracked,
              avgPct: (glance.avgCompletion * 100).round(),
              perfectDays: glance.perfectDays,
            ),
          ),
        ),
      ],
    );
  }

  String _fmtRate(double rate, double? delta) {
    final pct = '${(rate * 100).round()}%';
    if (delta == null) return pct;
    final deltaPct = (delta.abs() * 100).round();
    if (deltaPct == 0) return pct;
    return '$pct ${delta > 0 ? '↑' : '↓'}$deltaPct%';
  }

  // ── Computation helpers ───────────────────────────────────────────────────

  _QuickGlance _computeQuickGlance(DateTime now, int shieldedDays) {
    var daysTracked = 0;
    var totalDue = 0;
    var totalDone = 0;
    var perfectDays = 0;
    final today = localMidnightUtc(now);
    final cutoff = localMidnightUtc(
        now.toLocal().subtract(const Duration(days: 364)));
    final vacDays = buildVacationDaySet(vacations);

    var d = cutoff;
    while (!d.isAfter(today)) {
      if (vacDays.contains(d)) { d = _nextDay(d); continue; }
      final dayLocal = d.toLocal();
      var due = 0;
      var done = 0;
      for (final h in habits) {
        final startUtc = localMidnightUtc(h.startDate.toLocal());
        if (d.isBefore(startUtc)) continue;
        if (h.endDate != null &&
            d.isAfter(localMidnightUtc(h.endDate!.toLocal()))) continue;
        final entry =
            effectiveScheduleAt(historyMap[h.id] ?? const [], d);
        if (!isDueOnSchedule(entry?.schedule ?? h.schedule, dayLocal)) {
          continue;
        }
        due++;
        final comps = yearlyMap[h.id] ?? const [];
        if (comps.any((c) => c.day.toUtc() == d)) done++;
      }
      if (due > 0) {
        daysTracked++;
        totalDue += due;
        totalDone += done;
        if (done == due) perfectDays++;
      }
      d = _nextDay(d);
    }
    var totalCompletions = 0;
    final activeIds = {for (final h in habits) h.id};
    for (final entry in yearlyMap.entries) {
      if (!activeIds.contains(entry.key)) continue;
      totalCompletions += entry.value.length;
    }
    return _QuickGlance(
      daysTracked: daysTracked,
      avgCompletion: totalDue == 0 ? 0 : totalDone / totalDue,
      perfectDays: perfectDays,
      totalCompletions: totalCompletions,
      shieldedDays: shieldedDays,
    );
  }

  _RatesData _computeRatesData(DateTime now, int days,
      {int offsetDays = 0}) {
    final today = localMidnightUtc(now);
    final vacDays = buildVacationDaySet(vacations);
    var totalDue = 0;
    var totalDone = 0;
    var greenDays = 0;
    var trackedDays = 0;

    final limit = days < 0 ? 365 : days;
    for (var i = offsetDays; i < offsetDays + limit; i++) {
      final dayLocal = now.toLocal().subtract(Duration(days: i));
      final day =
          DateTime(dayLocal.year, dayLocal.month, dayLocal.day);
      final dayUtc = localMidnightUtc(day);
      if (dayUtc.isAfter(today)) continue;
      if (vacDays.contains(dayUtc)) continue;

      var due = 0;
      var done = 0;
      for (final h in habits) {
        final startUtc = localMidnightUtc(h.startDate.toLocal());
        if (dayUtc.isBefore(startUtc)) continue;
        if (h.endDate != null &&
            dayUtc.isAfter(localMidnightUtc(h.endDate!.toLocal()))) {
          continue;
        }
        final entry =
            effectiveScheduleAt(historyMap[h.id] ?? const [], dayUtc);
        if (!isDueOnSchedule(entry?.schedule ?? h.schedule, day)) {
          continue;
        }
        due++;
        final comps = yearlyMap[h.id] ?? const [];
        if (comps.any((c) => c.day.toUtc() == dayUtc)) done++;
      }
      if (due > 0) {
        trackedDays++;
        totalDue += due;
        totalDone += done;
        if (done == due) greenDays++;
      }
    }
    return _RatesData(
      rate: totalDue == 0 ? 0 : totalDone / totalDue,
      greenDays: greenDays,
      trackedDays: trackedDays,
    );
  }

  _DowResult _computeDowRates(DateTime now, int days) {
    final today = localMidnightUtc(now);
    final vacDays = buildVacationDaySet(vacations);
    final dueCounts = List.filled(7, 0);
    final doneCounts = List.filled(7, 0);
    final limit = days < 0 ? 365 : days;
    for (var i = 0; i < limit; i++) {
      final dayLocal = now.toLocal().subtract(Duration(days: i));
      final day =
          DateTime(dayLocal.year, dayLocal.month, dayLocal.day);
      final dayUtc = localMidnightUtc(day);
      if (dayUtc.isAfter(today)) continue;
      if (vacDays.contains(dayUtc)) continue;
      final dow = (day.weekday - 1) % 7; // 0=Mon..6=Sun
      for (final h in habits) {
        final startUtc = localMidnightUtc(h.startDate.toLocal());
        if (dayUtc.isBefore(startUtc)) continue;
        if (h.endDate != null &&
            dayUtc.isAfter(localMidnightUtc(h.endDate!.toLocal()))) {
          continue;
        }
        final entry =
            effectiveScheduleAt(historyMap[h.id] ?? const [], dayUtc);
        if (!isDueOnSchedule(entry?.schedule ?? h.schedule, day)) {
          continue;
        }
        dueCounts[dow]++;
        final comps = yearlyMap[h.id] ?? const [];
        if (comps.any((c) => c.day.toUtc() == dayUtc)) doneCounts[dow]++;
      }
    }
    return _DowResult(
      rates: [
        for (var i = 0; i < 7; i++)
          dueCounts[i] == 0 ? 0.0 : doneCounts[i] / dueCounts[i],
      ],
      dueCounts: dueCounts,
    );
  }

  static DateTime _nextDay(DateTime d) {
    final local = d.toLocal();
    return DateTime(local.year, local.month, local.day + 1).toUtc();
  }
}

// ── Data models ───────────────────────────────────────────────────────────────

class _QuickGlance {
  final int daysTracked;
  final double avgCompletion;
  final int perfectDays;
  final int totalCompletions;
  final int shieldedDays;
  const _QuickGlance({
    required this.daysTracked,
    required this.avgCompletion,
    required this.perfectDays,
    required this.totalCompletions,
    required this.shieldedDays,
  });
}

class _RatesData {
  final double rate;
  final int greenDays;
  final int trackedDays;
  const _RatesData({
    required this.rate,
    required this.greenDays,
    required this.trackedDays,
  });
}

class _DowResult {
  final List<double> rates;
  final List<int> dueCounts;
  const _DowResult({required this.rates, required this.dueCounts});
}

class _ContribSummary {
  final int daysTracked;
  final int avgPct;
  final int perfectDays;
  const _ContribSummary({
    required this.daysTracked,
    required this.avgPct,
    required this.perfectDays,
  });
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _StatBlock extends StatelessWidget {
  final String label;
  final String comment;
  final Widget child;
  final AppColors col;

  const _StatBlock({
    required this.label,
    required this.comment,
    required this.child,
    required this.col,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: col.line),
        borderRadius: const BorderRadius.all(TH.r4),
      ),
      padding: const EdgeInsets.all(TH.s8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('● ',
                  style: TextStyle(color: col.green, fontSize: 12)),
              Text(label,
                  style: TextStyle(
                      color: col.fg,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          Text(comment,
              style: TextStyle(color: col.fgMute, fontSize: 11)),
          const SizedBox(height: TH.s8),
          child,
        ],
      ),
    );
  }
}

class _KV extends StatelessWidget {
  final String key_;
  final String value;
  final AppColors col;
  const _KV(this.key_, this.value, {required this.col});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text('$key_:',
                style: TextStyle(color: col.fgDim, fontSize: 12)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(color: col.green, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _PeriodPicker extends StatelessWidget {
  final int selectedIdx;
  final AppColors col;
  final ValueChanged<int> onChanged;

  const _PeriodPicker({
    required this.selectedIdx,
    required this.col,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      children: [
        for (var i = 0; i < _periods.length; i++)
          GestureDetector(
            onTap: () => onChanged(i),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: i == selectedIdx ? col.bg3 : Colors.transparent,
                border: Border.all(
                  color:
                      i == selectedIdx ? col.green : col.line2,
                ),
                borderRadius: const BorderRadius.all(TH.r4),
              ),
              child: Text(
                _periodLabels[i],
                style: TextStyle(
                  color: i == selectedIdx ? col.green : col.fgMute,
                  fontSize: 11,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _BarRow extends StatelessWidget {
  final String label;
  final double value;
  final AppColors col;
  const _BarRow(
      {required this.label, required this.value, required this.col});

  @override
  Widget build(BuildContext context) {
    const trackWidth = 160.0;
    final pct = '${(value * 100).round()}%';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(label,
                style: TextStyle(color: col.fgDim, fontSize: 11)),
          ),
          const SizedBox(width: TH.s8),
          SizedBox(
            width: trackWidth,
            height: 8,
            child: ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(2)),
              child: Stack(
                children: [
                  Container(color: col.bg3),
                  FractionallySizedBox(
                    widthFactor: value.clamp(0.0, 1.0),
                    child: Container(color: col.green),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: TH.s8),
          Text(pct,
              style: TextStyle(
                  color: value > 0 ? col.fg : col.fgMute,
                  fontSize: 11)),
        ],
      ),
    );
  }
}
