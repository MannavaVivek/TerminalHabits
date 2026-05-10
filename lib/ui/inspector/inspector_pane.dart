import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database.dart';
import '../../domain/schedule.dart';
import '../../domain/streaks.dart';
import '../../state/providers.dart';
import '../../theme/app_colors.dart';
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
    final focusedId = ref.watch(focusedHabitIdProvider);
    final habitsAV = ref.watch(habitsProvider);
    final recentAV = ref.watch(recentCompletionsProvider);
    final vacAV = ref.watch(vacationsProvider);

    Widget body = const _EmptyInspector();

    final historyAV = ref.watch(scheduleHistoryProvider);

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
        body = _HabitInspector(habit: habit, streaks: streaks, history: history);
      }
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
);

class _EmptyInspector extends StatelessWidget {
  const _EmptyInspector();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'select a habit\nto inspect',
        textAlign: TextAlign.center,
        style: TextStyle(color: context.col.fgFaint, fontSize: 12),
      ),
    );
  }
}

class _HabitInspector extends StatelessWidget {
  final Habit habit;
  final StreakResult streaks;
  final List<HabitScheduleHistoryData> history;
  const _HabitInspector(
      {required this.habit,
      required this.streaks,
      required this.history});

  @override
  Widget build(BuildContext context) {
    final col = context.col;
    final h = habit;
    final s = streaks;

    return ListView(
      padding: const EdgeInsets.all(TH.s14),
      children: [
        Text('${h.icon} ${h.name}',
            style: TextStyle(
                color: col.fg, fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: TH.s14),
        _Block(label: 'streak', col: col, children: [
          _Row('current', '${s.displayStreak}', col: col),
          _Row('longest', '${s.longest}', col: col),
          _Row('shields', '${s.shields}', col: col),
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
            width: 72,
            child: Text('$label:',
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
