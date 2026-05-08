import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../widgets/habit_group.dart';
import '../widgets/week_strip.dart';

class DailyView extends ConsumerWidget {
  const DailyView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dailyAV = ref.watch(dailyStateProvider);

    return dailyAV.when(
      loading: () => const Center(
          child: Text('loading...',
              style: TextStyle(color: TH.fgDim, fontSize: 13))),
      error: (e, _) => Center(
          child: Text('error: $e',
              style: const TextStyle(color: TH.red, fontSize: 13))),
      data: (state) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                TH.s14, TH.s14, TH.s14, 0),
            child: _DailyHeader(state: state),
          ),
          const SizedBox(height: TH.s14),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: TH.s14),
            child: WeekStrip(),
          ),
          const SizedBox(height: TH.s14),
          Expanded(
            child: state.groups.isEmpty
                ? const _EmptyState()
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: state.groups.length,
                    itemBuilder: (context, i) =>
                        HabitGroupWidget(dailyGroup: state.groups[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _DailyHeader extends ConsumerWidget {
  final DailyState state;
  const _DailyHeader({required this.state});

  static const _days = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday',
    'Friday', 'Saturday', 'Sunday',
  ];
  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userName =
        ref.watch(userNameProvider).valueOrNull ?? 'you';
    final day = state.today;
    final dateLine =
        '${_days[day.weekday - 1]}, ${_months[day.month - 1]} ${day.day} ${day.year}';
    final n = state.totalCompletionsAllTime;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Prompt line
        Text.rich(TextSpan(children: [
          TextSpan(
            text: userName,
            style: const TextStyle(color: TH.green, fontSize: 13),
          ),
          const TextSpan(
              text: '@TerminalHabits ',
              style: TextStyle(color: TH.fgDim, fontSize: 13)),
          const TextSpan(
              text: '\$ ',
              style: TextStyle(color: TH.fgMute, fontSize: 13)),
          const TextSpan(
              text: 'daily',
              style: TextStyle(color: TH.fg, fontSize: 13)),
        ])),
        const SizedBox(height: 4),
        // Comment line — completions count + tone-of-voice copy
        Text(
          _completionComment(n),
          style: const TextStyle(color: TH.fgMute, fontSize: 12),
        ),
        const SizedBox(height: TH.s8),
        // Calendar + date
        Row(
          children: [
            const Text('📆', style: TextStyle(fontSize: 13)),
            const SizedBox(width: TH.s8),
            Text(dateLine,
                style: const TextStyle(color: TH.fg, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 2),
        // Streak summary
        Row(
          children: [
            const Text('🔥', style: TextStyle(fontSize: 12)),
            const SizedBox(width: 4),
            Text('${state.maxCurrentStreak} days',
                style: const TextStyle(color: TH.amber, fontSize: 12)),
            const SizedBox(width: TH.s8),
            const Text('*',
                style: TextStyle(color: TH.fgMute, fontSize: 12)),
            const SizedBox(width: TH.s8),
            const Text('🛡', style: TextStyle(fontSize: 12)),
            const SizedBox(width: 4),
            Text('${state.sumShields}',
                style: const TextStyle(color: TH.blue, fontSize: 12)),
          ],
        ),
      ],
    );
  }
}

String _completionComment(int n) {
  if (n == 0) return '// just getting started.';
  if (n < 5) return '// $n completions. the first few stick. keep going.';
  if (n < 25) return '// $n completions. building habit-mass.';
  if (n < 50) {
    return "// $n completions. you're past the dabbling phase.";
  }
  if (n < 100) {
    return '// $n completions. the data is starting to mean something.';
  }
  if (n < 250) return '// $n completions. reps compound.';
  if (n < 500) return '// $n completions. the boring middle.';
  return '// $n completions. operator-level consistency.';
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('no habits yet.',
              style: TextStyle(color: TH.fgDim, fontSize: 14)),
          SizedBox(height: 8),
          Text('press ⌘N to add your first habit.',
              style: TextStyle(color: TH.fgFaint, fontSize: 13)),
        ],
      ),
    );
  }
}
