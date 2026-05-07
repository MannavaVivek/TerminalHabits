import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import 'habit_row.dart';

class HabitGroupWidget extends ConsumerStatefulWidget {
  final DailyGroup dailyGroup;
  const HabitGroupWidget({super.key, required this.dailyGroup});

  @override
  ConsumerState<HabitGroupWidget> createState() => _HabitGroupWidgetState();
}

class _HabitGroupWidgetState extends ConsumerState<HabitGroupWidget> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final g = widget.dailyGroup;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Container(
            color: Colors.transparent,
            padding: const EdgeInsets.symmetric(
                horizontal: TH.s14, vertical: TH.s8),
            child: Row(
              children: [
                Text(_expanded ? '▾ ' : '▸ ',
                    style:
                        const TextStyle(color: TH.fgMute, fontSize: 12)),
                Text(g.group.name,
                    style: const TextStyle(
                        color: TH.fgDim,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                const Spacer(),
                Text('[${g.doneCount}/${g.habits.length}]',
                    style:
                        const TextStyle(color: TH.fgFaint, fontSize: 12)),
              ],
            ),
          ),
        ),
        if (_expanded)
          ...g.habits.map((h) => HabitRow(dailyHabit: h)),
        Container(height: 1, color: TH.line),
      ],
    );
  }
}
