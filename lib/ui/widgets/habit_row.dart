import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../data/database.dart';
import '../../domain/streaks.dart';
import '../../state/providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/icon_library.dart';
import '../../theme/tokens.dart';
import '../modals/edit_habit_dialog.dart';
import '../modals/future_warn_dialog.dart';
import '../modals/habit_menu.dart';
import '../modals/value_input_dialog.dart';
import 'bordered_toast.dart';

class HabitRow extends ConsumerWidget {
  final DailyHabit dailyHabit;
  const HabitRow({super.key, required this.dailyHabit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final col = context.col;
    final h = dailyHabit.habit;
    final done = dailyHabit.isDoneToday;
    final focused = ref.watch(focusedHabitIdProvider) == h.id;
    final streak = dailyHabit.streaks.displayStreak;
    final streakAtRisk = dailyHabit.streaks.todayAtRisk;
    final selectedDay = ref.watch(selectedDayProvider);
    final isToday = _isToday(selectedDay);
    final streakStart = dailyHabit.streaks.streakStartUtc;
    final selectedDayUtc = localMidnightUtc(selectedDay);
    final inCurrentStreak =
        streakStart != null && !selectedDayUtc.isBefore(streakStart);
    final shieldedDays = ref.watch(dailyStateProvider).valueOrNull?.shieldedDays ?? const {};
    final isShieldedDay = shieldedDays.contains(selectedDayUtc);
    final iconColor = _colorFor(h.color, col);
    final iconData = lucideIconData(h.icon);

    void focus() =>
        ref.read(focusedHabitIdProvider.notifier).state = h.id;

    Widget row = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: focus,
      onLongPress: () {
        showHabitMenu(context, ref, h);
      },
      onSecondaryTapDown: (details) =>
          showHabitMenu(context, ref, h, at: details.globalPosition),
      child: Container(
        color: focused ? col.bg2 : Colors.transparent,
        padding: const EdgeInsets.symmetric(
            horizontal: TH.s22, vertical: TH.s8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
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
                      child: _CheckWidget(done: done, col: col),
                    ),
                  ),
                ),

                if (iconData != null)
                  Icon(iconData, size: 14, color: iconColor)
                else
                  Text(h.icon,
                      style: TextStyle(
                          color: iconColor, fontSize: 13)),
                const SizedBox(width: TH.s8),

                Expanded(
                  child: Text(h.name,
                      style: TextStyle(
                          color: done ? col.fgDim : col.fg,
                          fontSize: 14,
                          decoration: done
                              ? TextDecoration.lineThrough
                              : null,
                          decorationColor: col.fgMute)),
                ),

                const SizedBox(width: TH.s8),
                SizedBox(
                  width: 44,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // If the day is shielded and this habit wasn't done, show shield icon.
                      if (isShieldedDay && !done)
                        Icon(LucideIcons.shield, size: 13, color: col.blue)
                      else
                        Icon(
                          LucideIcons.flame,
                          size: 13,
                          color: isToday
                              ? (streak > 0
                                  ? (streakAtRisk ? col.fgDim : col.amber)
                                  : col.fgFaint)
                              : (inCurrentStreak && done ? col.amber : col.fgFaint),
                        ),
                      const SizedBox(width: 3),
                      if (isToday && streak > 0)
                        Text('$streak',
                            style: TextStyle(
                                color: streakAtRisk ? col.fgDim : col.amber,
                                fontSize: 12)),
                    ],
                  ),
                ),
                SizedBox(
                  width: 56,
                  child: h.tracking != 'checkbox'
                      ? Text(
                          _progressLabel(h, dailyHabit.todayValue),
                          textAlign: TextAlign.right,
                          style: TextStyle(
                              color: done ? col.green : col.fgMute,
                              fontSize: 11),
                        )
                      : null,
                ),
              ],
            ),
            if (h.note != null && h.note!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 44, top: 2),
                child: Text('// ${h.note}',
                    style: TextStyle(
                        color: col.fgFaint, fontSize: 11)),
              ),
          ],
        ),
      ),
    );

    // On Android: swipe-left archives the habit; swipe-right opens edit.
    if (!Platform.isAndroid) return row;

    final db = ref.read(dbProvider);
    return Dismissible(
      key: ValueKey(h.id),
      direction: DismissDirection.horizontal,
      // Red background for left-swipe (archive), amber for right-swipe (edit).
      background: _SwipeBg(color: col.amber, label: 'edit', align: Alignment.centerLeft),
      secondaryBackground: _SwipeBg(color: col.red, label: 'archive', align: Alignment.centerRight),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Right swipe → open edit dialog, don't remove the row.
          await EditHabitDialog.show(context, h);
          return false;
        } else {
          // Left swipe → archive.
          HapticFeedback.mediumImpact();
          return true;
        }
      },
      onDismissed: (_) {
        db.archiveHabit(h.id);
        showBorderedToast(
          context,
          '${h.name} archived',
          undoLabel: 'undo',
          onUndo: () => db.unarchiveHabit(h.id),
        );
      },
      child: row,
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
      final allowFuture =
          ref.read(allowFutureMarkingProvider).valueOrNull ?? false;
      if (!allowFuture) {
        await confirmFutureToggle(context);
        return;
      }
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

  static String _progressLabel(Habit h, double value) {
    final v = value.toInt().clamp(0, 999);
    if (h.tracking == 'duration') {
      final t = (h.target ?? 0).clamp(0, 999);
      return t > 0 ? '$v/${t}m' : '${v}m';
    }
    final t = (h.target ?? 0).clamp(0, 999);
    return t > 0 ? '$v/$t' : '$v';
  }

  static bool _isToday(DateTime day) {
    final now = DateTime.now();
    return day.year == now.year && day.month == now.month && day.day == now.day;
  }

  static Color _colorFor(String color, AppColors col) {
    switch (color) {
      case 'amber':
        return col.amber;
      case 'blue':
        return col.blue;
      case 'purple':
        return col.purple;
      case 'teal':
        return col.teal;
      case 'red':
        return col.red;
      default:
        return col.green;
    }
  }
}

class _SwipeBg extends StatelessWidget {
  final Color color;
  final String label;
  final AlignmentGeometry align;
  const _SwipeBg({required this.color, required this.label, required this.align});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color.withValues(alpha: 0.15),
      padding: const EdgeInsets.symmetric(horizontal: TH.s22),
      alignment: align,
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class _CheckWidget extends StatelessWidget {
  final bool done;
  final AppColors col;
  const _CheckWidget({required this.done, required this.col});

  @override
  Widget build(BuildContext context) {
    return Text(
      done ? '[✓]' : '[ ]',
      style: TextStyle(
          color: done ? col.green : col.fgMute, fontSize: 13),
    );
  }
}
