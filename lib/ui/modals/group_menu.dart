import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database.dart';
import '../../state/providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/tokens.dart';
import '../widgets/icon_picker.dart';
import 'text_prompt.dart';

Future<void> showGroupMenu(
  BuildContext context,
  WidgetRef ref,
  Group group, {
  Offset? at,
}) async {
  final col = AppColors.of(context);
  final overlay =
      Overlay.of(context).context.findRenderObject() as RenderBox?;
  final position = at ?? overlay?.localToGlobal(Offset.zero) ?? Offset.zero;
  final size = overlay?.size ?? Size.zero;
  final isGeneral = group.id == 'general';

  final selected = await showMenu<String>(
    context: context,
    color: col.bg2,
    position: RelativeRect.fromLTRB(
      position.dx,
      position.dy,
      size.width - position.dx,
      size.height - position.dy,
    ),
    items: [
      if (!isGeneral)
        PopupMenuItem(
          value: 'rename',
          child: Text('rename', style: TextStyle(color: col.fg, fontSize: 13)),
        ),
      PopupMenuItem(
        value: 'icon',
        child: Text('edit icon', style: TextStyle(color: col.fg, fontSize: 13)),
      ),
      PopupMenuItem(
        value: 'note',
        child: Text('edit note', style: TextStyle(color: col.fg, fontSize: 13)),
      ),
      if (!isGeneral)
        PopupMenuItem(
          value: 'delete',
          child: Text('delete', style: TextStyle(color: col.red, fontSize: 13)),
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
        maxLength: 40,
      );
      if (name == null) return;
      final trimmed = name.trim();
      if (trimmed.isEmpty) {
        // Empty name = treat as delete, per Phase 12 spec.
        if (!context.mounted) return;
        await _confirmDelete(context, ref, group);
      } else if (trimmed != group.name) {
        await db.renameGroup(group.id, trimmed);
      }
    case 'icon':
      if (!context.mounted) return;
      final key =
          await IconPickerDialog.show(context, initial: group.icon);
      if (key != null) {
        await db.patchGroup(
            group.id, GroupsCompanion(icon: Value(key)));
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
  if (group.id == 'general') return;
  final col = AppColors.of(context);
  final db = ref.read(dbProvider);
  final userId = ref.read(currentUserIdProvider);
  final allGroups = await db.getGroups(userId);
  final reassignTargets =
      allGroups.where((g) => g.id != group.id).toList();
  // Count all non-deleted habits (active + archived) — they all get
  // affected when the group is removed.
  final allHabits = await db.getAllHabits(userId);
  final affected = allHabits
      .where((h) => h.groupId == group.id && !h.deleted)
      .length;

  if (!context.mounted) return;

  // Default choice: reassign to first available group (usually general).
  String? choice = reassignTargets.isNotEmpty
      ? reassignTargets.first.id
      : 'cascade';

  final confirmed = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black54,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => Dialog(
        backgroundColor: col.bg2,
        shape: RoundedRectangleBorder(
            borderRadius: const BorderRadius.all(TH.r10)),
        child: SizedBox(
          width: 420,
          child: Padding(
            padding: const EdgeInsets.all(TH.s22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('delete group "${group.name}"?',
                    style: TextStyle(
                        color: col.fg,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: TH.s8),
                if (affected == 0)
                  Text('no habits in this group.',
                      style:
                          TextStyle(color: col.fgDim, fontSize: 12))
                else
                  Text(
                      '$affected habit${affected == 1 ? '' : 's'} in this group.',
                      style:
                          TextStyle(color: col.fgDim, fontSize: 12)),
                if (affected > 0) ...[
                  const SizedBox(height: TH.s14),
                  for (final t in reassignTargets)
                    _RadioRow(
                      label: 'move to "${t.name}"',
                      selected: choice == t.id,
                      col: col,
                      onTap: () => setState(() => choice = t.id),
                    ),
                  _RadioRow(
                    label: 'delete habits',
                    danger: true,
                    selected: choice == 'cascade',
                    col: col,
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
    ),
  );

  if (confirmed != true) return;
  if (choice == 'cascade' || affected == 0) {
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
  final AppColors col;

  const _RadioRow({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.col,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? (danger ? col.red : col.green)
        : col.fgMute;
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
                    color: selected ? col.fg : col.fgDim, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
