import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database.dart';
import '../../state/providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/tokens.dart';
import 'edit_habit_dialog.dart';

Future<void> showHabitMenu(
  BuildContext context,
  WidgetRef ref,
  Habit habit, {
  Offset? at,
}) async {
  final col = AppColors.of(context);
  final overlay =
      Overlay.of(context).context.findRenderObject() as RenderBox?;
  final position = at ?? overlay?.localToGlobal(Offset.zero) ?? Offset.zero;
  final size = overlay?.size ?? Size.zero;

  final action = await showMenu<String>(
    context: context,
    color: col.bg2,
    position: RelativeRect.fromLTRB(
      position.dx,
      position.dy,
      size.width - position.dx,
      size.height - position.dy,
    ),
    items: [
      PopupMenuItem(
        value: 'edit',
        child: Text('edit', style: TextStyle(color: col.fg, fontSize: 13)),
      ),
      PopupMenuItem(
        value: 'archive',
        child: Text('archive',
            style: TextStyle(color: col.fgDim, fontSize: 13)),
      ),
      PopupMenuItem(
        value: 'delete',
        child: Text('delete', style: TextStyle(color: col.red, fontSize: 13)),
      ),
    ],
  );

  if (action == null) return;
  if (!context.mounted) return;
  final db = ref.read(dbProvider);

  switch (action) {
    case 'edit':
      await EditHabitDialog.show(context, habit);
    case 'archive':
      await db.archiveHabit(habit.id);
    case 'delete':
      if (!context.mounted) return;
      final confirmed = await _confirmDelete(context, habit);
      if (confirmed) await db.deleteHabit(habit.id);
  }
}

Future<bool> _confirmDelete(BuildContext context, Habit habit) async {
  final col = AppColors.of(context);
  final result = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black54,
    builder: (ctx) => Dialog(
      backgroundColor: col.bg2,
      shape:
          RoundedRectangleBorder(borderRadius: const BorderRadius.all(TH.r10)),
      child: SizedBox(
        width: 400,
        child: Padding(
          padding: const EdgeInsets.all(TH.s22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('delete "${habit.name}"?',
                  style: TextStyle(
                      color: col.fg,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: TH.s8),
              Text(
                'this removes the habit and every completion record. '
                'archive instead if you want to keep the history.',
                style: TextStyle(color: col.fgDim, fontSize: 12),
              ),
              const SizedBox(height: TH.s22),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(ctx).pop(false),
                    child: Text('[ cancel ]',
                        style:
                            TextStyle(color: col.fgMute, fontSize: 12)),
                  ),
                  const SizedBox(width: TH.s14),
                  GestureDetector(
                    onTap: () => Navigator.of(ctx).pop(true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: TH.s14, vertical: TH.s8),
                      decoration: BoxDecoration(
                        border: Border.all(color: col.red),
                        borderRadius: const BorderRadius.all(TH.r4),
                      ),
                      child: Text('[ delete ]',
                          style:
                              TextStyle(color: col.red, fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
  return result ?? false;
}
