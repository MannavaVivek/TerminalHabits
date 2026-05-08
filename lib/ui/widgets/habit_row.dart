import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database.dart';
import '../../domain/streaks.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../modals/future_warn_dialog.dart';

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

    void focus() =>
        ref.read(focusedHabitIdProvider.notifier).state = h.id;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: focus,
      child: Container(
        color: focused ? TH.bg2 : Colors.transparent,
        padding: const EdgeInsets.symmetric(
            horizontal: TH.s22, vertical: TH.s8),
        child: Row(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () async {
                focus();
                await _toggle(context, ref, h);
              },
              child: Padding(
                padding: const EdgeInsets.only(right: TH.s8),
                child: SizedBox(
                  width: 28,
                  child: Text(done ? '[✓]' : '[ ]',
                      style: TextStyle(
                          color: done ? TH.green : TH.fgMute,
                          fontSize: 13)),
                ),
              ),
            ),
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

  Future<void> _toggle(
      BuildContext context, WidgetRef ref, Habit h) async {
    final selectedDay = ref.read(selectedDayProvider);
    final now = DateTime.now();
    final selDate =
        DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
    final today = DateTime(now.year, now.month, now.day);

    if (selDate.isAfter(today)) {
      await confirmFutureToggle(context);
      return;
    }

    final db = ref.read(dbProvider);
    final dayUtc = localMidnightUtc(selectedDay);
    await db.toggleCompletion(h.id, dayUtc);
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
