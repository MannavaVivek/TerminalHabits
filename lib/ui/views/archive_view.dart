import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database.dart';
import '../../state/providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/icon_library.dart';
import '../../theme/tokens.dart';

class ArchiveView extends ConsumerWidget {
  const ArchiveView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final col = context.col;
    final archivedAV = ref.watch(archivedHabitsProvider);
    final groupsAV = ref.watch(groupsProvider);

    return archivedAV.when(
      loading: () => Center(
        child: Text('loading...',
            style: TextStyle(color: col.fgDim, fontSize: 13)),
      ),
      error: (e, _) => Center(
        child: Text('error: $e',
            style: TextStyle(color: col.red, fontSize: 13)),
      ),
      data: (archived) {
        final groups = groupsAV.valueOrNull ?? const <Group>[];
        final groupName = {for (final g in groups) g.id: g.name};

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  TH.s14, TH.s14, TH.s14, TH.s8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('archive',
                      style: TextStyle(
                          color: col.fg,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    archived.isEmpty
                        ? '// nothing here yet.'
                        : '// ${archived.length} habit${archived.length == 1 ? '' : 's'} archived. restore to bring back to daily.',
                    style: TextStyle(
                        color: col.fgMute, fontSize: 12),
                  ),
                ],
              ),
            ),
            Container(height: 1, color: col.line),
            Expanded(
              child: archived.isEmpty
                  ? Center(
                      child: Text(
                        'no archived habits',
                        style: TextStyle(
                            color: col.fgFaint, fontSize: 13),
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: archived.length,
                      itemBuilder: (_, i) => _ArchivedRow(
                        habit: archived[i],
                        groupLabel: groupName[archived[i].groupId] ??
                            archived[i].groupId,
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _ArchivedRow extends ConsumerWidget {
  final Habit habit;
  final String groupLabel;
  const _ArchivedRow({required this.habit, required this.groupLabel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final col = context.col;
    final db = ref.read(dbProvider);
    final archivedOn = habit.archivedAt;

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: TH.s22, vertical: TH.s8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: col.line, width: 1)),
      ),
      child: Row(
        children: [
          () {
            final d = lucideIconData(habit.icon);
            return d != null
                ? Icon(d, size: 14, color: col.fgDim)
                : Text(habit.icon,
                    style:
                        TextStyle(color: col.fgDim, fontSize: 13));
          }(),
          const SizedBox(width: TH.s8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(habit.name,
                    style: TextStyle(
                        color: col.fgDim, fontSize: 14)),
                const SizedBox(height: 2),
                Text(
                  archivedOn == null
                      ? groupLabel
                      : '$groupLabel · archived ${_relative(archivedOn)}',
                  style: TextStyle(
                      color: col.fgFaint, fontSize: 11),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () async {
              await db.unarchiveHabit(habit.id);
            },
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: TH.s8, vertical: 4),
              child: Text('[ restore ]',
                  style: TextStyle(color: col.green, fontSize: 12)),
            ),
          ),
          GestureDetector(
            onTap: () async {
              final confirmed = await _confirmDelete(context, habit);
              if (confirmed) await db.deleteHabit(habit.id);
            },
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: TH.s8, vertical: 4),
              child: Text('[ delete ]',
                  style: TextStyle(color: col.red, fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }
}

String _relative(DateTime when) {
  final diff = DateTime.now().difference(when);
  if (diff.inDays >= 1) return '${diff.inDays}d ago';
  if (diff.inHours >= 1) return '${diff.inHours}h ago';
  if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
  return 'just now';
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
              Text('permanently delete "${habit.name}"?',
                  style: TextStyle(
                      color: col.fg,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: TH.s8),
              Text(
                "this removes the habit and every completion record.",
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
