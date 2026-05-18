import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/tokens.dart';

const _kThemes = [
  (id: 'matrix',    label: 'matrix',    accent: Color(0xFF5CE39A), bg: Color(0xFF0B1014)),
  (id: 'hacker',    label: 'hacker',    accent: Color(0xFF00FF41), bg: Color(0xFF000000)),
  (id: 'nord',      label: 'nord',      accent: Color(0xFF88C0D0), bg: Color(0xFF2E3440)),
  (id: 'solarized', label: 'solarized', accent: Color(0xFF268BD2), bg: Color(0xFF002B36)),
  (id: 'monokai',   label: 'monokai',   accent: Color(0xFFA6E22E), bg: Color(0xFF272822)),
  (id: 'gruvbox',   label: 'gruvbox',   accent: Color(0xFFB8BB26), bg: Color(0xFF282828)),
];

class SettingsDialog extends ConsumerWidget {
  const SettingsDialog({super.key});

  static Future<void> show(BuildContext context) => showDialog<void>(
        context: context,
        barrierColor: Colors.black54,
        builder: (_) => const SettingsDialog(),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final col = context.col;
    final db = ref.read(dbProvider);
    final themeId = ref.watch(themeIdProvider).valueOrNull ?? 'matrix';
    final fontSize = ref.watch(fontSizeProvider).valueOrNull ?? 'md';
    final allowFuture =
        ref.watch(allowFutureMarkingProvider).valueOrNull ?? false;
    final confirmDest =
        ref.watch(confirmDestructiveProvider).valueOrNull ?? true;
    return Dialog(
      backgroundColor: col.bg2,
      shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(TH.r10)),
      child: SizedBox(
        width: 520,
        height: 600,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  TH.s22, TH.s14, TH.s14, TH.s14),
              child: Row(
                children: [
                  Text('[ ⚙ settings ]',
                      style: TextStyle(
                          color: col.fg,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Padding(
                      padding: const EdgeInsets.all(TH.s8),
                      child: Text('✕',
                          style: TextStyle(color: col.fgMute, fontSize: 13)),
                    ),
                  ),
                ],
              ),
            ),
            Container(height: 1, color: col.line),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(TH.s22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel('appearance', col),
                    const SizedBox(height: TH.s14),
                    _SettingRow(
                      label: 'font size',
                      col: col,
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
                                  color: sel ? col.bg3 : Colors.transparent,
                                  border: Border.all(
                                      color: sel ? col.green : col.line2),
                                  borderRadius:
                                      const BorderRadius.all(TH.r4),
                                ),
                                child: Text(s,
                                    style: TextStyle(
                                        color: sel ? col.green : col.fgDim,
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
                      col: col,
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
                                            sel ? col.amber : col.line2,
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
                        ],
                      ),
                    ),
                    const SizedBox(height: TH.s22),
                    _sectionLabel('behavior', col),
                    const SizedBox(height: TH.s14),
                    _SettingRow(
                      label: 'future marking',
                      col: col,
                      child: _Toggle(
                        value: allowFuture,
                        col: col,
                        onToggle: (v) => db.setSetting(
                            'allowFutureMarking', v.toString()),
                      ),
                    ),
                    const SizedBox(height: TH.s8),
                    _SettingRow(
                      label: 'confirm delete',
                      col: col,
                      child: _Toggle(
                        value: confirmDest,
                        col: col,
                        onToggle: (v) => db.setSetting(
                            'confirmDestructive', v.toString()),
                      ),
                    ),
                    const SizedBox(height: TH.s22),
                    _sectionLabel('about', col),
                    const SizedBox(height: TH.s14),
                    _AboutRow('version', '0.3.0', col: col),
                    _AboutRow('storage', 'local sqlite', col: col),
                    const SizedBox(height: TH.s8),
                    Text(
                      '// passwords are stored in plaintext — Phase 11\n'
                      '// replaces this with hashed storage + email recovery.',
                      style: TextStyle(color: col.fgFaint, fontSize: 10),
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

Widget _sectionLabel(String label, AppColors col) => Text('── $label',
    style: TextStyle(
        color: col.fgMute, fontSize: 11, fontWeight: FontWeight.w600));

class _SettingRow extends StatelessWidget {
  final String label;
  final Widget child;
  final CrossAxisAlignment labelAlign;
  final AppColors col;

  const _SettingRow({
    required this.label,
    required this.child,
    required this.col,
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
              style: TextStyle(color: col.fgDim, fontSize: 12)),
        ),
        Expanded(child: child),
      ],
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
        padding: const EdgeInsets.symmetric(
            horizontal: TH.s8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: value ? col.green : col.line2),
          borderRadius: const BorderRadius.all(TH.r4),
        ),
        child: Text(
          value ? '[ ■ enabled ]' : '[   disabled ]',
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
            width: 80,
            child: Text('$label:',
                style: TextStyle(
                    color: col.fgDim, fontSize: 12)),
          ),
          Text(value,
              style: TextStyle(color: col.fg, fontSize: 12)),
        ],
      ),
    );
  }
}

