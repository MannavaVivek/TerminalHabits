import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../data/database.dart';
import '../../domain/streaks.dart';
import '../../state/providers.dart';
import '../../theme/icon_library.dart';
import '../../theme/tokens.dart';
import '../modals/future_warn_dialog.dart';
import '../modals/habit_menu.dart';
import '../modals/value_input_dialog.dart';

class HabitRow extends ConsumerWidget {
  final DailyHabit dailyHabit;
  const HabitRow({super.key, required this.dailyHabit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final h = dailyHabit.habit;
    final done = dailyHabit.isDoneToday;
    final focused = ref.watch(focusedHabitIdProvider) == h.id;
    final streak = dailyHabit.streaks.current;
    final iconColor = _colorFor(h.color);
    final iconData = lucideIconData(h.icon);

    void focus() =>
        ref.read(focusedHabitIdProvider.notifier).state = h.id;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: focus,
      onLongPress: () => showHabitMenu(context, ref, h),
      onSecondaryTapDown: (details) =>
          showHabitMenu(context, ref, h, at: details.globalPosition),
      child: Container(
        color: focused ? TH.bg2 : Colors.transparent,
        padding: const EdgeInsets.symmetric(
            horizontal: TH.s22, vertical: TH.s8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // ── checkbox / counter / duration tap area ────────
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () async {
                    focus();
                    await _handleTap(context, ref, h);
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(right: TH.s8),
                    child: SizedBox(
                      width: 36,
                      child: _CheckWidget(done: done),
                    ),
                  ),
                ),

                // ── icon ──────────────────────────────────────────
                if (iconData != null)
                  Icon(iconData, size: 14, color: iconColor)
                else
                  Text(h.icon,
                      style: TextStyle(
                          color: iconColor, fontSize: 13)),
                const SizedBox(width: TH.s8),

                // ── name ──────────────────────────────────────────
                Expanded(
                  child: Text(h.name,
                      style: TextStyle(
                          color: done ? TH.fgDim : TH.fg,
                          fontSize: 14,
                          decoration: done
                              ? TextDecoration.lineThrough
                              : null,
                          decorationColor: TH.fgMute)),
                ),

                // ── streak flame ──────────────────────────────────
                if (streak > 0) ...[
                  const SizedBox(width: TH.s8),
                  Icon(LucideIcons.flame,
                      size: 13, color: TH.amber),
                  const SizedBox(width: 2),
                  Text('$streak',
                      style: const TextStyle(
                          color: TH.amber, fontSize: 12)),
                ],

                // ── counter / duration progress ───────────────────
                if (h.tracking == 'counter' && h.target != null) ...[
                  const SizedBox(width: TH.s8),
                  Text(
                    '${dailyHabit.todayValue.toInt()}/${h.target}',
                    style: TextStyle(
                        color: done ? TH.green : TH.fgMute,
                        fontSize: 11),
                  ),
                ] else if (h.tracking == 'duration' &&
                    h.target != null) ...[
                  const SizedBox(width: TH.s8),
                  Text(
                    '${dailyHabit.todayValue.toInt()}/${h.target}min',
                    style: TextStyle(
                        color: done ? TH.green : TH.fgMute,
                        fontSize: 11),
                  ),
                ],

                // ── target time ───────────────────────────────────
                if (h.targetTime != null &&
                    h.targetTime!.isNotEmpty) ...[
                  const SizedBox(width: TH.s8),
                  Icon(LucideIcons.clock,
                      size: 11, color: TH.fgMute),
                  const SizedBox(width: 2),
                  Text(h.targetTime!,
                      style: const TextStyle(
                          color: TH.fgMute, fontSize: 11)),
                ],
              ],
            ),
            if (h.note != null && h.note!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 44, top: 2),
                child: Text('// ${h.note}',
                    style: const TextStyle(
                        color: TH.fgFaint, fontSize: 11)),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleTap(
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

    switch (h.tracking) {
      case 'counter':
      case 'duration':
        if (!context.mounted) return;
        final result = await ValueInputDialog.show(
          context,
          habit: h,
          currentValue: dailyHabit.todayValue,
        );
        if (result == null) return;
        if (result <= 0) {
          await db.clearCompletion(h.id, dayUtc);
        } else {
          await db.setCompletionValue(h.id, dayUtc, result);
        }
      default:
        await db.toggleCompletion(h.id, dayUtc);
    }
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

class _CheckWidget extends StatelessWidget {
  final bool done;
  const _CheckWidget({required this.done});

  @override
  Widget build(BuildContext context) {
    return Text(
      done ? '[✓]' : '[ ]',
      style: TextStyle(
          color: done ? TH.green : TH.fgMute, fontSize: 13),
    );
  }
}
