import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../state/providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/icon_library.dart';
import '../../theme/tokens.dart';
import '../modals/group_menu.dart';
import 'habit_row.dart';

class HabitGroupWidget extends ConsumerWidget {
  final DailyGroup dailyGroup;
  const HabitGroupWidget({super.key, required this.dailyGroup});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final col = context.col;
    final g = dailyGroup;
    final collapsed = g.group.collapsed;
    final note = g.group.note;
    final iconKey = g.group.icon;
    final done = g.doneCount;
    final total = g.habits.length;
    final allDone = total > 0 && done == total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: () => ref
              .read(dbProvider)
              .setGroupCollapsed(g.group.id, !collapsed),
          onLongPressStart: (details) =>
              showGroupMenu(context, ref, g.group,
                  at: details.globalPosition),
          onSecondaryTapDown: (details) =>
              showGroupMenu(context, ref, g.group,
                  at: details.globalPosition),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: TH.s14, vertical: TH.s8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(
                        lucideIconData(iconKey) ?? LucideIcons.folder,
                        size: 13,
                        color: col.fgDim,
                      ),
                    ),
                    Text(g.group.name,
                        style: TextStyle(
                            color: col.fgDim,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Text('[$done/$total]',
                        style: TextStyle(
                            color: allDone ? col.green : col.fgFaint,
                            fontSize: 12)),
                    const SizedBox(width: TH.s8),
                    Icon(
                      collapsed
                          ? LucideIcons.chevronRight
                          : LucideIcons.chevronDown,
                      size: 13,
                      color: col.fgMute,
                    ),
                  ],
                ),
                if (note != null && note.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text('// $note',
                        style: TextStyle(
                            color: col.fgFaint, fontSize: 11)),
                  ),
              ],
            ),
          ),
        ),
        if (!collapsed) ...g.habits.map((h) => HabitRow(dailyHabit: h)),
        Container(height: 1, color: col.line),
      ],
    );
  }
}
