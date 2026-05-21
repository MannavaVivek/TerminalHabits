import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database.dart';
import '../../domain/schedule.dart';
import '../../domain/streaks.dart';
import '../../state/providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/icon_library.dart';
import '../../theme/tokens.dart';

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _fmtDate(DateTime d) =>
    '${_months[d.month - 1]} ${d.day} ${d.year}';

class InspectorPane extends ConsumerWidget {
  const InspectorPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentView = ref.watch(currentViewProvider);
    final focusedId = ref.watch(focusedHabitIdProvider);
    final habitsAV = ref.watch(habitsProvider);
    final recentAV = ref.watch(recentCompletionsProvider);
    final vacAV = ref.watch(vacationsProvider);
    final historyAV = ref.watch(scheduleHistoryProvider);
    final shieldsAV = ref.watch(dayShieldsProvider);
    final selectedDay = ref.watch(selectedDayProvider);

    // Stats view → show glossary
    if (currentView == 'stats') {
      return const SizedBox(width: 280, child: _StatsGlossary());
    }

    // Vacation view → show vacation info
    if (currentView == 'vacation') {
      return const SizedBox(width: 280, child: _VacationInspector());
    }

    // Daily view on a vacation day → show nothing
    if (currentView == 'daily' && vacAV.hasValue) {
      final selMidnight = DateTime(
          selectedDay.year, selectedDay.month, selectedDay.day);
      final inVacation = vacAV.requireValue.any((v) {
        if (!v.active) return false;
        final s = DateTime(v.start.toLocal().year, v.start.toLocal().month,
            v.start.toLocal().day);
        final e = DateTime(v.end.toLocal().year, v.end.toLocal().month,
            v.end.toLocal().day);
        return !selMidnight.isBefore(s) && !selMidnight.isAfter(e);
      });
      if (inVacation) return const SizedBox(width: 280);
    }

    Widget body;

    if (focusedId != null &&
        habitsAV.hasValue &&
        recentAV.hasValue &&
        vacAV.hasValue &&
        historyAV.hasValue) {
      final habits = habitsAV.requireValue;
      final habit = habits.firstWhere(
        (h) => h.id == focusedId,
        orElse: () => habits.isEmpty ? _stubHabit : habits.first,
      );
      if (habit.id == focusedId) {
        final comps = recentAV.requireValue[habit.id] ?? const [];
        final history = historyAV.requireValue[habit.id] ?? const [];
        final streaks = computeStreaks(
            habit, comps, DateTime.now(), vacAV.requireValue, history);
        body = _HabitInspector(
          habit: habit,
          streaks: streaks,
          history: history,
          comps: comps,
          shieldedDays: shieldsAV.valueOrNull ?? const {},
        );
      } else {
        body = _TodaySummary(
          habitsAV: habitsAV,
          recentAV: recentAV,
          vacAV: vacAV,
          historyAV: historyAV,
        );
      }
    } else {
      // Daily view, no habit focused → Today summary
      body = _TodaySummary(
        habitsAV: habitsAV,
        recentAV: recentAV,
        vacAV: vacAV,
        historyAV: historyAV,
      );
    }

    return SizedBox(width: 280, child: body);
  }
}

final _stubHabit = Habit(
  id: -1,
  userId: 0,
  groupId: '',
  name: '',
  icon: '',
  color: 'green',
  tracking: 'checkbox',
  target: null,
  unit: null,
  schedule: '{"days":[]}',
  note: null,
  targetTime: null,
  sortIndex: 0,
  healthSource: null,
  createdAt: DateTime(1970),
  startDate: DateTime(1970),
  endDate: null,
  archivedAt: null,
  updatedAt: DateTime(1970),
  deleted: false,
);

class _TodaySummary extends StatelessWidget {
  final AsyncValue<List<Habit>> habitsAV;
  final AsyncValue<Map<int, List<Completion>>> recentAV;
  final AsyncValue<List<Vacation>> vacAV;
  final AsyncValue<Map<int, List<HabitScheduleHistoryData>>> historyAV;

  const _TodaySummary({
    required this.habitsAV,
    required this.recentAV,
    required this.vacAV,
    required this.historyAV,
  });

  @override
  Widget build(BuildContext context) {
    final col = context.col;

    if (!habitsAV.hasValue || !recentAV.hasValue) {
      return Center(
        child: Text('loading…',
            style: TextStyle(color: col.fgFaint, fontSize: 12)),
      );
    }

    final habits = habitsAV.requireValue;
    final recentMap = recentAV.requireValue;
    final vacList = vacAV.valueOrNull ?? const [];
    final historyMap = historyAV.valueOrNull ?? const {};
    final now = DateTime.now();
    final todayUtc = DateTime(now.year, now.month, now.day).toUtc();

    var dueToday = 0;
    var doneToday = 0;
    var activeStreaks = 0;

    for (final h in habits) {
      final startUtc =
          DateTime(h.startDate.toLocal().year, h.startDate.toLocal().month,
              h.startDate.toLocal().day).toUtc();
      if (todayUtc.isBefore(startUtc)) continue;
      if (h.endDate != null) {
        final endUtc = DateTime(h.endDate!.toLocal().year,
            h.endDate!.toLocal().month, h.endDate!.toLocal().day).toUtc();
        if (todayUtc.isAfter(endUtc)) continue;
      }
      final entry = effectiveScheduleAt(
          historyMap[h.id] ?? const [], todayUtc);
      if (!isDueOnSchedule(entry?.schedule ?? h.schedule, now)) continue;
      dueToday++;
      final comps = recentMap[h.id] ?? const [];
      if (comps.any((c) => c.day.toUtc() == todayUtc)) doneToday++;
    }

    for (final h in habits) {
      final comps = recentMap[h.id] ?? const [];
      final history = historyMap[h.id] ?? const [];
      final s = computeStreaks(h, comps, now, vacList, history);
      if (s.current > 0) activeStreaks++;
    }

    return ListView(
      padding: const EdgeInsets.all(TH.s14),
      children: [
        Text('── today',
            style: TextStyle(color: col.fgMute, fontSize: 11)),
        const SizedBox(height: TH.s4),
        _Row('done', '$doneToday', col: col),
        _Row('remaining', '${(dueToday - doneToday).clamp(0, 999)}', col: col),
        const SizedBox(height: TH.s8),
        Text('── streaks',
            style: TextStyle(color: col.fgMute, fontSize: 11)),
        const SizedBox(height: TH.s4),
        _Row('active', '$activeStreaks', col: col),
        if (!Platform.isAndroid) ...[
          const SizedBox(height: TH.s14),
          Text(
            'j/k to focus a habit\nspace to toggle\ne to edit\na to archive',
            style: TextStyle(color: col.fgFaint, fontSize: 11, height: 1.6),
          ),
        ],
      ],
    );
  }
}

class _StatsGlossary extends StatelessWidget {
  const _StatsGlossary();

  @override
  Widget build(BuildContext context) {
    final col = context.col;
    return ListView(
      padding: const EdgeInsets.all(TH.s14),
      children: [
        Text('── glossary',
            style: TextStyle(color: col.fgMute, fontSize: 11)),
        const SizedBox(height: TH.s8),
        _GlossaryItem(
          term: 'overview',
          def: 'Total habits, completions in the last 365 days, active streaks, and 30-day compliance rate.',
          col: col,
        ),
        _GlossaryItem(
          term: 'streaks',
          def: 'Top 5 habits by current streak and by longest streak (up to 365-day window).',
          col: col,
        ),
        _GlossaryItem(
          term: 'rates',
          def: 'Per-habit completion rate over the last 30 days: done ÷ due.',
          col: col,
        ),
        _GlossaryItem(
          term: 'contributions',
          def: '365-day grid. Color intensity = number of completions that day (5 levels).',
          col: col,
        ),
        _GlossaryItem(
          term: 'day of week',
          def: 'Average completion rate per weekday over the last 90 days.',
          col: col,
        ),
      ],
    );
  }
}

class _GlossaryItem extends StatelessWidget {
  final String term;
  final String def;
  final AppColors col;
  const _GlossaryItem({required this.term, required this.def, required this.col});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: TH.s8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(term, style: TextStyle(color: col.amber, fontSize: 11)),
          const SizedBox(height: 2),
          Text(def,
              style: TextStyle(color: col.fgDim, fontSize: 11, height: 1.5)),
        ],
      ),
    );
  }
}

class _VacationInspector extends StatelessWidget {
  const _VacationInspector();

  @override
  Widget build(BuildContext context) {
    final col = context.col;
    return Padding(
      padding: const EdgeInsets.all(TH.s14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('── vacation',
              style: TextStyle(color: col.fgMute, fontSize: 11)),
          const SizedBox(height: TH.s8),
          Text(
            'During a vacation, streak decay is paused.',
            style: TextStyle(color: col.fgDim, fontSize: 11, height: 1.5),
          ),
          const SizedBox(height: TH.s8),
          Text(
            'Habit completions still count toward stats but not toward streaks.',
            style: TextStyle(color: col.fgDim, fontSize: 11, height: 1.5),
          ),
          const SizedBox(height: TH.s8),
          Text(
            'Vacation days are treated as neutral in the overall day-wise streak.',
            style: TextStyle(color: col.fgDim, fontSize: 11, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _HabitInspector extends StatelessWidget {
  final Habit habit;
  final StreakResult streaks;
  final List<HabitScheduleHistoryData> history;
  final List<Completion> comps;
  final Set<DateTime> shieldedDays;
  const _HabitInspector({
    required this.habit,
    required this.streaks,
    required this.history,
    required this.comps,
    required this.shieldedDays,
  });

  @override
  Widget build(BuildContext context) {
    final col = context.col;
    final h = habit;
    final s = streaks;

    // Count completions + shielded days where this habit was due but not done.
    final completedDayUtcs = {for (final c in comps) c.day.toUtc()};
    var shieldedBonus = 0;
    for (final dayUtc in shieldedDays) {
      if (completedDayUtcs.contains(dayUtc)) continue;
      final local = dayUtc.toLocal();
      final d = DateTime(local.year, local.month, local.day);
      final hStart = localMidnightUtc(h.startDate.toLocal());
      if (dayUtc.isBefore(hStart)) continue;
      if (h.endDate != null &&
          dayUtc.isAfter(localMidnightUtc(h.endDate!.toLocal()))) continue;
      final entry = effectiveScheduleAt(history, dayUtc);
      if (!isDueOnSchedule(entry?.schedule ?? h.schedule, d)) continue;
      shieldedBonus++;
    }
    final completedCount = completedDayUtcs.length + shieldedBonus;

    return ListView(
      padding: const EdgeInsets.all(TH.s14),
      children: [
        Row(
          children: [
            () {
              final iconData = lucideIconData(h.icon);
              if (iconData != null) {
                return Icon(iconData, size: 14, color: col.fg);
              }
              return Text(h.icon,
                  style: TextStyle(color: col.fg, fontSize: 14));
            }(),
            const SizedBox(width: 6),
            Flexible(
              child: Text(h.name,
                  style: TextStyle(
                      color: col.fg,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: TH.s14),
        _Block(label: 'streak', col: col, children: [
          _Row('current', '${s.displayStreak}', col: col),
          _Row('longest', '${s.longest}', col: col),
          _Row('done (90d)', '$completedCount', col: col),
        ]),
        const SizedBox(height: TH.s8),
        _Block(label: 'habit', col: col, children: [
          _Row('tracking', h.tracking, col: col),
          _Row('schedule', scheduleLabel(h.schedule), col: col),
          _Row('started', _fmtDate(h.startDate.toLocal()), col: col),
          if (h.endDate != null)
            _Row('ends', _fmtDate(h.endDate!.toLocal()), col: col),
          if (h.note != null && h.note!.isNotEmpty)
            _Row('note', h.note!, col: col),
        ]),
        if (history.length > 1) ...[
          const SizedBox(height: TH.s8),
          _Block(
            label: 'schedule history',
            col: col,
            children: [
              for (final e in history)
                _Row(
                  _fmtDate(e.effectiveFrom.toLocal()),
                  scheduleLabel(e.schedule),
                  col: col,
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Block extends StatelessWidget {
  final String label;
  final List<Widget> children;
  final AppColors col;
  const _Block({required this.label, required this.children, required this.col});

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
          Text('── $label',
              style: TextStyle(color: col.fgMute, fontSize: 11)),
          const SizedBox(height: TH.s4),
          ...children,
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final AppColors col;
  const _Row(this.label, this.value, {required this.col});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text('$label:',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: col.fgDim, fontSize: 12)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(color: col.fg, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
