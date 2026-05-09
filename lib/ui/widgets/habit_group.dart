import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../state/providers.dart';
import '../../theme/icon_library.dart';
import '../../theme/tokens.dart';
import '../modals/group_menu.dart';
import 'habit_row.dart';

class HabitGroupWidget extends ConsumerWidget {
  final DailyGroup dailyGroup;
  const HabitGroupWidget({super.key, required this.dailyGroup});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          onLongPress: () => showGroupMenu(context, ref, g.group),
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
                    if (iconKey != null && lucideIconData(iconKey) != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Icon(lucideIconData(iconKey)!,
                            size: 13, color: TH.fgDim),
                      ),
                    Text(g.group.name,
                        style: const TextStyle(
                            color: TH.fgDim,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Text('[$done/$total]',
                        style: TextStyle(
                            color: allDone ? TH.green : TH.fgFaint,
                            fontSize: 12)),
                    const SizedBox(width: TH.s8),
                    Icon(
                      collapsed
                          ? LucideIcons.chevronRight
                          : LucideIcons.chevronDown,
                      size: 13,
                      color: TH.fgMute,
                    ),
                  ],
                ),
                if (note != null && note.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 0, top: 2),
                    child: Text('// $note',
                        style: const TextStyle(
                            color: TH.fgFaint, fontSize: 11)),
                  ),
              ],
            ),
          ),
        ),
        if (!collapsed) ...g.habits.map((h) => HabitRow(dailyHabit: h)),
        Container(height: 1, color: TH.line),
      ],
    );
  }
}
