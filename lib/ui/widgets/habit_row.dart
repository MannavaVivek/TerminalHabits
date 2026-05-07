import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database.dart';
import '../../domain/streaks.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';

class HabitRow extends ConsumerWidget {
  final DailyHabit dailyHabit;
  const HabitRow({super.key, required this.dailyHabit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final h = dailyHabit.habit;
    final done = dailyHabit.isDoneToday;
    final focused = ref.watch(focusedHabitIdProvider) == h.id;
    final streak = dailyHabit.streaks.current;
    final shields = dailyHabit.streaks.shields;

    return GestureDetector(
      onTap: () {
        ref.read(focusedHabitIdProvider.notifier).state = h.id;
        _toggle(ref, h);
      },
      child: Container(
        color: focused ? TH.bg2 : Colors.transparent,
        padding: const EdgeInsets.symmetric(
            horizontal: TH.s22, vertical: TH.s8),
        child: Row(
          children: [
            Text(done ? '[✓]' : '[ ]',
                style: TextStyle(
                    color: done ? TH.green : TH.fgMute, fontSize: 13)),
            const SizedBox(width: TH.s8),
            Text(h.icon,
                style: TextStyle(
                    color: _colorFor(h.color), fontSize: 13)),
            const SizedBox(width: TH.s8),
            Expanded(
              child: Text(h.name,
                  style: TextStyle(
                      color: done ? TH.fgDim : TH.fg,
                      fontSize: 14,
                      decoration:
                          done ? TextDecoration.lineThrough : null,
                      decorationColor: TH.fgMute)),
            ),
            if (streak > 0) ...[
              const SizedBox(width: TH.s8),
              Text('$streak ▲',
                  style: const TextStyle(
                      color: TH.amber, fontSize: 12)),
            ],
            if (shields > 0) ...[
              const SizedBox(width: 4),
              Text('$shields ⬡',
                  style: const TextStyle(
                      color: TH.blue, fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }

  void _toggle(WidgetRef ref, Habit h) {
    final db = ref.read(dbProvider);
    final todayUtc = localMidnightUtc(DateTime.now());
    db.toggleCompletion(h.id, todayUtc);
  }

  static Color _colorFor(String color) {
    switch (color) {
      case 'amber':
        return TH.amber;
      case 'blue':
        return TH.blue;
      case 'purple':
        return TH.purple;
      case 'teal':
        return TH.teal;
      case 'red':
        return TH.red;
      default:
        return TH.green;
    }
  }
}
