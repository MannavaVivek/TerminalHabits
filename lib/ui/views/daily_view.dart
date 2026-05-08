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
            child: _PromptHeader(today: state.today),
          ),
          const SizedBox(height: TH.s8),
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

class _PromptHeader extends StatelessWidget {
  final DateTime today;
  const _PromptHeader({required this.today});

  static const _days = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
  ];
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final dayLabel =
        '${_days[today.weekday - 1]} ${today.day} ${_months[today.month - 1]} ${today.year}';
    return Text.rich(TextSpan(children: [
      const TextSpan(
          text: 'you',
          style: TextStyle(color: TH.green, fontSize: 13)),
      const TextSpan(
          text: '@TerminalHabits',
          style: TextStyle(color: TH.fgDim, fontSize: 13)),
      const TextSpan(
          text: '\$ ',
          style: TextStyle(color: TH.fgMute, fontSize: 13)),
      TextSpan(
          text: 'daily — $dayLabel',
          style: const TextStyle(color: TH.fg, fontSize: 13)),
    ]));
  }
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
