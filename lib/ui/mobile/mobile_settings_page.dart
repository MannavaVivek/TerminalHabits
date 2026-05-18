import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database.dart';
import '../../state/providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/tokens.dart';
import 'mobile_sub_page.dart';

const _kThemes = [
  (id: 'matrix',    label: 'matrix',    accent: Color(0xFF5CE39A), bg: Color(0xFF0B1014)),
  (id: 'hacker',    label: 'hacker',    accent: Color(0xFF00FF41), bg: Color(0xFF000000)),
  (id: 'nord',      label: 'nord',      accent: Color(0xFF88C0D0), bg: Color(0xFF2E3440)),
  (id: 'solarized', label: 'solarized', accent: Color(0xFF268BD2), bg: Color(0xFF002B36)),
  (id: 'monokai',   label: 'monokai',   accent: Color(0xFFA6E22E), bg: Color(0xFF272822)),
  (id: 'gruvbox',   label: 'gruvbox',   accent: Color(0xFFB8BB26), bg: Color(0xFF282828)),
];

class MobileSettingsPage extends ConsumerWidget {
  const MobileSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final col = context.col;
    final db = ref.read(dbProvider);
    final themeId = ref.watch(themeIdProvider).valueOrNull ?? 'matrix';
    final allowFuture = ref.watch(allowFutureMarkingProvider).valueOrNull ?? false;
    final confirmDest = ref.watch(confirmDestructiveProvider).valueOrNull ?? true;

    final currentTheme = _kThemes.firstWhere(
      (t) => t.id == themeId,
      orElse: () => _kThemes.first,
    );

    return MobileSubPage(
      title: 'settings',
      child: ListView(
        padding: const EdgeInsets.all(TH.s14),
        children: [
          // ── appearance ──────────────────────────────────────────────────
          _SectionLabel('appearance', col),
          const SizedBox(height: TH.s8),
          _SettingRow(
            label: 'theme',
            col: col,
            child: GestureDetector(
              onTap: () => _openThemePicker(context, ref, themeId, db),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10, height: 10,
                    decoration: BoxDecoration(
                      color: currentTheme.bg,
                      border: Border.all(color: currentTheme.accent, width: 1),
                    ),
                  ),
                  const SizedBox(width: TH.s8),
                  Text(currentTheme.label,
                      style: TextStyle(color: col.green, fontSize: 12)),
                  const SizedBox(width: TH.s4),
                  Text('›', style: TextStyle(color: col.fgMute, fontSize: 14)),
                ],
              ),
            ),
          ),
          const SizedBox(height: TH.s22),
          // ── behavior ────────────────────────────────────────────────────
          _SectionLabel('behavior', col),
          const SizedBox(height: TH.s8),
          _SettingRow(
            label: 'future marking',
            col: col,
            child: _Toggle(
              value: allowFuture,
              col: col,
              onToggle: (v) => db.setSetting('allowFutureMarking', v.toString()),
            ),
          ),
          const SizedBox(height: TH.s8),
          _SettingRow(
            label: 'confirm delete',
            col: col,
            child: _Toggle(
              value: confirmDest,
              col: col,
              onToggle: (v) =>
                  db.setSetting('confirmDestructive', v.toString()),
            ),
          ),
          const SizedBox(height: TH.s22),
          // ── about ───────────────────────────────────────────────────────
          _SectionLabel('about', col),
          const SizedBox(height: TH.s8),
          _AboutRow('version', '0.3.0', col: col),
          _AboutRow('storage', 'local sqlite', col: col),
        ],
      ),
    );
  }

  Future<void> _openThemePicker(
    BuildContext context,
    WidgetRef ref,
    String currentId,
    AppDatabase db,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (_) => _ThemePickerDialog(originalId: currentId, db: db),
    );
    // null = dismissed (tapped outside) → revert to original
    if (confirmed != true) {
      await db.setSetting('themeId', currentId);
    }
  }
}

// ── Theme picker dialog ───────────────────────────────────────────────────────

class _ThemePickerDialog extends StatefulWidget {
  final String originalId;
  final AppDatabase db;
  const _ThemePickerDialog({required this.originalId, required this.db});

  @override
  State<_ThemePickerDialog> createState() => _ThemePickerDialogState();
}

class _ThemePickerDialogState extends State<_ThemePickerDialog> {
  late String _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.originalId;
  }

  @override
  Widget build(BuildContext context) {
    final col = context.col;
    return Dialog(
      backgroundColor: col.bg2,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(TH.r10)),
      child: Padding(
        padding: const EdgeInsets.all(TH.s22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('select theme',
                style: TextStyle(
                    color: col.fg,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: TH.s14),
            ..._kThemes.map((t) {
              final isSel = _selected == t.id;
              return GestureDetector(
                onTap: () {
                  setState(() => _selected = t.id);
                  widget.db.setSetting('themeId', t.id);
                },
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Text(isSel ? '[●]' : '[ ]',
                          style: TextStyle(
                              color: isSel ? t.accent : col.fgMute,
                              fontSize: 13)),
                      const SizedBox(width: TH.s8),
                      Container(
                        width: 12, height: 12,
                        decoration: BoxDecoration(
                          color: t.bg,
                          border: Border.all(color: t.accent, width: 1),
                        ),
                      ),
                      const SizedBox(width: TH.s8),
                      Text(t.label,
                          style: TextStyle(
                              color: isSel ? col.fg : col.fgDim,
                              fontSize: 13)),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: TH.s14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(null),
                  child: Text('[ cancel ]',
                      style: TextStyle(color: col.fgMute, fontSize: 12)),
                ),
                const SizedBox(width: TH.s14),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: TH.s14, vertical: TH.s8),
                    decoration: BoxDecoration(
                      border: Border.all(color: col.green),
                      borderRadius: const BorderRadius.all(TH.r4),
                    ),
                    child: Text('[ apply ]',
                        style: TextStyle(color: col.green, fontSize: 12)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final AppColors col;
  const _SectionLabel(this.label, this.col);

  @override
  Widget build(BuildContext context) => Text('── $label',
      style: TextStyle(
          color: col.fgMute,
          fontSize: 11,
          fontWeight: FontWeight.w600));
}

class _SettingRow extends StatelessWidget {
  final String label;
  final Widget child;
  final AppColors col;
  const _SettingRow({required this.label, required this.child, required this.col});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text('$label:',
                style: TextStyle(color: col.fgDim, fontSize: 12)),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onToggle;
  final AppColors col;
  const _Toggle({required this.value, required this.onToggle, required this.col});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onToggle(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: TH.s8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: value ? col.green : col.line2),
          borderRadius: const BorderRadius.all(TH.r4),
        ),
        child: Text(
          value ? '[ ■ on ]' : '[   off ]',
          style: TextStyle(
              color: value ? col.green : col.fgMute, fontSize: 12),
        ),
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  final String label;
  final String value;
  final AppColors col;
  const _AboutRow(this.label, this.value, {required this.col});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text('$label:',
                style: TextStyle(color: col.fgDim, fontSize: 12)),
          ),
          Text(value, style: TextStyle(color: col.fg, fontSize: 12)),
        ],
      ),
    );
  }
}
