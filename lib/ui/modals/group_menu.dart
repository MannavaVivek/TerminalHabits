import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import 'text_prompt.dart';

// Shows the right-click / long-press menu for a group header.
Future<void> showGroupMenu(
  BuildContext context,
  WidgetRef ref,
  Group group, {
  Offset? at,
}) async {
  final overlay =
      Overlay.of(context).context.findRenderObject() as RenderBox?;
  final position = at ?? overlay?.localToGlobal(Offset.zero) ?? Offset.zero;
  final size = overlay?.size ?? Size.zero;

  final selected = await showMenu<String>(
    context: context,
    color: TH.bg2,
    position: RelativeRect.fromLTRB(
      position.dx,
      position.dy,
      size.width - position.dx,
      size.height - position.dy,
    ),
    items: const [
      PopupMenuItem(
        value: 'rename',
        child: Text('rename', style: TextStyle(color: TH.fg, fontSize: 13)),
      ),
      PopupMenuItem(
        value: 'note',
        child: Text('edit note', style: TextStyle(color: TH.fg, fontSize: 13)),
      ),
      PopupMenuItem(
        value: 'delete',
        child: Text('delete', style: TextStyle(color: TH.red, fontSize: 13)),
      ),
    ],
  );

  if (selected == null) return;
  if (!context.mounted) return;

  final db = ref.read(dbProvider);
  switch (selected) {
    case 'rename':
      final name = await promptText(
        context,
        title: 'rename group',
        hint: 'group name',
        initial: group.name,
      );
      if (name != null && name.isNotEmpty) {
        await db.renameGroup(group.id, name);
      }
    case 'note':
      final note = await promptText(
        context,
        title: 'group note',
        hint: '// optional comment',
        initial: group.note ?? '',
      );
      if (note != null) {
        await db.setGroupNote(group.id, note.isEmpty ? null : note);
      }
    case 'delete':
      if (!context.mounted) return;
      await _confirmDelete(context, ref, group);
  }
}

Future<void> _confirmDelete(
    BuildContext context, WidgetRef ref, Group group) async {
  final db = ref.read(dbProvider);
  final allGroups = await db.getGroups();
  final reassignTargets =
      allGroups.where((g) => g.id != group.id).toList();
  final habitsInGroup = await db.getActiveHabits();
  final affected =
      habitsInGroup.where((h) => h.groupId == group.id).length;

  if (!context.mounted) return;

  // 'cascade' or a group id to reassign to.
  String? choice = reassignTargets.isNotEmpty
      ? reassignTargets.first.id
      : 'cascade';

  final confirmed = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black54,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => Dialog(
        backgroundColor: TH.bg2,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(TH.r10)),
        child: SizedBox(
          width: 420,
          child: Padding(
            padding: const EdgeInsets.all(TH.s22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('delete group "${group.name}"?',
                    style: const TextStyle(
                        color: TH.fg,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: TH.s8),
                if (affected == 0)
                  const Text('no habits in this group.',
                      style:
                          TextStyle(color: TH.fgDim, fontSize: 12))
                else
                  Text('$affected habit${affected == 1 ? '' : 's'} in this group.',
                      style: const TextStyle(
                          color: TH.fgDim, fontSize: 12)),
                if (affected > 0) ...[
                  const SizedBox(height: TH.s14),
                  for (final t in reassignTargets)
                    _RadioRow(
                      label: 'reassign to "${t.name}"',
                      selected: choice == t.id,
                      onTap: () => setState(() => choice = t.id),
                    ),
                  _RadioRow(
                    label: 'delete habits + completions',
                    danger: true,
                    selected: choice == 'cascade',
                    onTap: () =>
                        setState(() => choice = 'cascade'),
                  ),
                ],
                const SizedBox(height: TH.s14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(ctx).pop(false),
                      child: const Text('[ cancel ]',
                          style:
                              TextStyle(color: TH.fgMute, fontSize: 12)),
                    ),
                    const SizedBox(width: TH.s14),
                    GestureDetector(
                      onTap: () => Navigator.of(ctx).pop(true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: TH.s14, vertical: TH.s8),
                        decoration: BoxDecoration(
                          border: Border.all(color: TH.red),
                          borderRadius: BorderRadius.all(TH.r4),
                        ),
                        child: const Text('[ delete ]',
                            style:
                                TextStyle(color: TH.red, fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  if (confirmed != true) return;
  if (choice == 'cascade') {
    await db.deleteGroup(group.id);
  } else {
    await db.deleteGroup(group.id, reassignTo: choice);
  }
}

class _RadioRow extends StatelessWidget {
  final String label;
  final bool selected;
  final bool danger;
  final VoidCallback onTap;

  const _RadioRow({
    required this.label,
    required this.selected,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? (danger ? TH.red : TH.green)
        : TH.fgMute;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Text(selected ? '(•)' : '( )',
                style: TextStyle(color: color, fontSize: 13)),
            const SizedBox(width: TH.s8),
            Text(label,
                style: TextStyle(
                    color: selected ? TH.fg : TH.fgDim, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
