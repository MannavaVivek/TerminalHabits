import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database.dart';
import '../../state/providers.dart';
import '../../theme/icon_library.dart';
import '../../theme/tokens.dart';

// ── Theme swatches (preview only — full apply requires restart) ───────────────

const _kThemes = [
  (id: 'matrix',    label: 'matrix',    accent: Color(0xFF5CE39A), bg: Color(0xFF0B1014)),
  (id: 'hacker',    label: 'hacker',    accent: Color(0xFF00FF41), bg: Color(0xFF000000)),
  (id: 'nord',      label: 'nord',      accent: Color(0xFF88C0D0), bg: Color(0xFF2E3440)),
  (id: 'solarized', label: 'solarized', accent: Color(0xFF268BD2), bg: Color(0xFF002B36)),
  (id: 'monokai',   label: 'monokai',   accent: Color(0xFFA6E22E), bg: Color(0xFF272822)),
  (id: 'gruvbox',   label: 'gruvbox',   accent: Color(0xFFB8BB26), bg: Color(0xFF282828)),
];

// ─────────────────────────────────────────────────────────────────────────────

class SettingsDialog extends ConsumerWidget {
  const SettingsDialog({super.key});

  static Future<void> show(BuildContext context) => showDialog<void>(
        context: context,
        barrierColor: Colors.black54,
        builder: (_) => const SettingsDialog(),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.read(dbProvider);
    final themeId = ref.watch(themeIdProvider).valueOrNull ?? 'matrix';
    final fontSize = ref.watch(fontSizeProvider).valueOrNull ?? 'md';
    final allowFuture =
        ref.watch(allowFutureMarkingProvider).valueOrNull ?? false;
    final confirmDest =
        ref.watch(confirmDestructiveProvider).valueOrNull ?? true;
    final archivedAV = ref.watch(archivedHabitsProvider);
    final groupsAV = ref.watch(groupsProvider);

    return Dialog(
      backgroundColor: TH.bg2,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(TH.r10)),
      child: SizedBox(
        width: 520,
        height: 600,
        child: Column(
          children: [
            // ── header ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  TH.s22, TH.s14, TH.s14, TH.s14),
              child: Row(
                children: [
                  const Text('[ ⚙ settings ]',
                      style: TextStyle(
                          color: TH.fg,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Padding(
                      padding: EdgeInsets.all(TH.s8),
                      child: Text('✕',
                          style: TextStyle(color: TH.fgMute, fontSize: 13)),
                    ),
                  ),
                ],
              ),
            ),
            Container(height: 1, color: TH.line),
            // ── body ────────────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(TH.s22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Appearance ────────────────────────────────────────
                    _sectionLabel('appearance'),
                    const SizedBox(height: TH.s14),
                    _SettingRow(
                      label: 'font size',
                      child: Row(
                        children: ['sm', 'md', 'lg'].map((s) {
                          final sel = fontSize == s;
                          return Padding(
                            padding: const EdgeInsets.only(right: TH.s8),
                            child: GestureDetector(
                              onTap: () => db.setSetting('fontSize', s),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: TH.s8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: sel ? TH.bg3 : Colors.transparent,
                                  border: Border.all(
                                      color: sel ? TH.green : TH.line2),
                                  borderRadius:
                                      const BorderRadius.all(TH.r4),
                                ),
                                child: Text(s,
                                    style: TextStyle(
                                        color: sel ? TH.green : TH.fgDim,
                                        fontSize: 12)),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: TH.s14),
                    _SettingRow(
                      label: 'theme',
                      labelAlign: CrossAxisAlignment.start,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: TH.s8,
                            runSpacing: TH.s8,
                            children: _kThemes.map((t) {
                              final sel = themeId == t.id;
                              return GestureDetector(
                                onTap: () =>
                                    db.setSetting('themeId', t.id),
                                child: Container(
                                  width: 76,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: TH.s8, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: t.bg,
                                    border: Border.all(
                                        color:
                                            sel ? TH.amber : TH.line2,
                                        width: sel ? 1.5 : 1),
                                    borderRadius:
                                        const BorderRadius.all(TH.r4),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: t.accent,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      Expanded(
                                        child: Text(t.label,
                                            overflow:
                                                TextOverflow.ellipsis,
                                            style: TextStyle(
                                                color: t.accent
                                                    .withValues(alpha: 0.9),
                                                fontSize: 10)),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            '// color takes effect on next launch',
                            style: TextStyle(
                                color: TH.fgFaint, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: TH.s22),
                    // ── Behavior ──────────────────────────────────────────
                    _sectionLabel('behavior'),
                    const SizedBox(height: TH.s14),
                    _SettingRow(
                      label: 'future marking',
                      child: _Toggle(
                        value: allowFuture,
                        onToggle: (v) => db.setSetting(
                            'allowFutureMarking', v.toString()),
                      ),
                    ),
                    const SizedBox(height: TH.s8),
                    _SettingRow(
                      label: 'confirm delete',
                      child: _Toggle(
                        value: confirmDest,
                        onToggle: (v) => db.setSetting(
                            'confirmDestructive', v.toString()),
                      ),
                    ),
                    const SizedBox(height: TH.s22),
                    // ── Data ──────────────────────────────────────────────
                    _sectionLabel('data'),
                    const SizedBox(height: TH.s14),
                    _ArchiveList(
                      archivedAV: archivedAV,
                      groupsAV: groupsAV,
                      db: db,
                    ),
                    const SizedBox(height: TH.s22),
                    // ── About ─────────────────────────────────────────────
                    _sectionLabel('about'),
                    const SizedBox(height: TH.s14),
                    const _AboutRow('version', '0.3.0'),
                    const _AboutRow('storage', 'local sqlite'),
                    const SizedBox(height: TH.s8),
                    const Text(
                      '// passwords are stored in plaintext — Phase 11\n'
                      '// replaces this with hashed storage + email recovery.',
                      style: TextStyle(color: TH.fgFaint, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

Widget _sectionLabel(String label) => Text('── $label',
    style: const TextStyle(
        color: TH.fgMute, fontSize: 11, fontWeight: FontWeight.w600));

class _SettingRow extends StatelessWidget {
  final String label;
  final Widget child;
  final CrossAxisAlignment labelAlign;

  const _SettingRow({
    required this.label,
    required this.child,
    this.labelAlign = CrossAxisAlignment.center,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: labelAlign,
      children: [
        SizedBox(
          width: 110,
          child: Text('$label:',
              style: const TextStyle(color: TH.fgDim, fontSize: 12)),
        ),
        Expanded(child: child),
      ],
    );
  }
}

class _Toggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onToggle;
  const _Toggle({required this.value, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onToggle(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: TH.s8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: value ? TH.green : TH.line2),
          borderRadius: const BorderRadius.all(TH.r4),
        ),
        child: Text(
          value ? '[ ■ enabled ]' : '[   disabled ]',
          style: TextStyle(
              color: value ? TH.green : TH.fgMute, fontSize: 12),
        ),
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  final String label;
  final String value;
  const _AboutRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text('$label:',
                style: const TextStyle(
                    color: TH.fgDim, fontSize: 12)),
          ),
          Text(value,
              style: const TextStyle(color: TH.fg, fontSize: 12)),
        ],
      ),
    );
  }
}

// ── Archive list ──────────────────────────────────────────────────────────────

class _ArchiveList extends ConsumerWidget {
  final AsyncValue<List<Habit>> archivedAV;
  final AsyncValue<List<Group>> groupsAV;
  final AppDatabase db;

  const _ArchiveList({
    required this.archivedAV,
    required this.groupsAV,
    required this.db,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return archivedAV.when(
      loading: () => const Text('loading...',
          style: TextStyle(color: TH.fgDim, fontSize: 12)),
      error: (e, _) => Text('error: $e',
          style: const TextStyle(color: TH.red, fontSize: 12)),
      data: (archived) {
        final groups = groupsAV.valueOrNull ?? const <Group>[];
        final groupName = {for (final g in groups) g.id: g.name};

        if (archived.isEmpty) {
          return const Text('// no archived habits.',
              style: TextStyle(color: TH.fgMute, fontSize: 11));
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '// ${archived.length} habit${archived.length == 1 ? '' : 's'} archived.',
              style: const TextStyle(color: TH.fgMute, fontSize: 11),
            ),
            const SizedBox(height: TH.s8),
            ...archived.map(
              (h) => _ArchivedItem(
                habit: h,
                groupLabel: groupName[h.groupId] ?? h.groupId,
                db: db,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ArchivedItem extends StatelessWidget {
  final Habit habit;
  final String groupLabel;
  final AppDatabase db;
  const _ArchivedItem(
      {required this.habit, required this.groupLabel, required this.db});

  String _relative(DateTime when) {
    final diff = DateTime.now().difference(when);
    if (diff.inDays >= 1) return '${diff.inDays}d ago';
    if (diff.inHours >= 1) return '${diff.inHours}h ago';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
    return 'just now';
  }

  @override
  Widget build(BuildContext context) {
    final archivedOn = habit.archivedAt;
    final iconData = lucideIconData(habit.icon);

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 0, vertical: TH.s8),
      decoration: const BoxDecoration(
        border: Border(
            bottom: BorderSide(color: TH.line, width: 1)),
      ),
      child: Row(
        children: [
          if (iconData != null)
            Icon(iconData, size: 13, color: TH.fgDim)
          else
            Text(habit.icon,
                style: const TextStyle(
                    color: TH.fgDim, fontSize: 12)),
          const SizedBox(width: TH.s8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(habit.name,
                    style: const TextStyle(
                        color: TH.fgDim, fontSize: 13)),
                Text(
                  archivedOn == null
                      ? groupLabel
                      : '$groupLabel · ${_relative(archivedOn)}',
                  style: const TextStyle(
                      color: TH.fgFaint, fontSize: 10),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => db.unarchiveHabit(habit.id),
            child: const Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: TH.s8, vertical: 4),
              child: Text('[ restore ]',
                  style: TextStyle(
                      color: TH.green, fontSize: 11)),
            ),
          ),
          GestureDetector(
            onTap: () => _confirmAndDelete(context),
            child: const Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: TH.s8, vertical: 4),
              child: Text('[ delete ]',
                  style: TextStyle(
                      color: TH.red, fontSize: 11)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAndDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => Dialog(
        backgroundColor: TH.bg2,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(TH.r10)),
        child: SizedBox(
          width: 400,
          child: Padding(
            padding: const EdgeInsets.all(TH.s22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('permanently delete "${habit.name}"?',
                    style: const TextStyle(
                        color: TH.fg,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: TH.s8),
                const Text(
                  'this removes the habit and every completion record.',
                  style: TextStyle(color: TH.fgDim, fontSize: 12),
                ),
                const SizedBox(height: TH.s22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(ctx).pop(false),
                      child: const Text('[ cancel ]',
                          style: TextStyle(
                              color: TH.fgMute, fontSize: 12)),
                    ),
                    const SizedBox(width: TH.s14),
                    GestureDetector(
                      onTap: () => Navigator.of(ctx).pop(true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: TH.s14, vertical: TH.s8),
                        decoration: BoxDecoration(
                          border: Border.all(color: TH.red),
                          borderRadius:
                              const BorderRadius.all(TH.r4),
                        ),
                        child: const Text('[ delete ]',
                            style: TextStyle(
                                color: TH.red, fontSize: 12)),
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
    if (ok == true) await db.deleteHabit(habit.id);
  }
}
