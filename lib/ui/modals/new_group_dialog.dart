import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../theme/app_colors.dart';
import '../../theme/icon_library.dart';
import '../../theme/tokens.dart';
import '../widgets/icon_picker.dart';

class NewGroupResult {
  final String name;
  final String? note;
  final String? icon;
  const NewGroupResult({required this.name, this.note, this.icon});
}

class NewGroupDialog extends StatefulWidget {
  const NewGroupDialog({super.key});

  static Future<NewGroupResult?> show(BuildContext context) =>
      showDialog<NewGroupResult>(
        context: context,
        barrierColor: Colors.black54,
        builder: (_) => const NewGroupDialog(),
      );

  @override
  State<NewGroupDialog> createState() => _NewGroupDialogState();
}

class _NewGroupDialogState extends State<NewGroupDialog> {
  final _nameCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String? _icon;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(NewGroupResult(
      name: name,
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      icon: _icon,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final col = context.col;
    final iconData = lucideIconData(_icon);

    final keyboardH = MediaQuery.viewInsetsOf(context).bottom;
    final screenH = MediaQuery.sizeOf(context).height;
    return Dialog(
      backgroundColor: col.bg2,
      shape:
          RoundedRectangleBorder(borderRadius: const BorderRadius.all(TH.r10)),
      insetPadding: EdgeInsets.fromLTRB(12, 12, 12, keyboardH + 12),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 380,
          maxHeight: screenH - keyboardH - 48,
        ),
        child: SingleChildScrollView(
          child: Padding(
          padding: const EdgeInsets.all(TH.s22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('new group',
                      style: TextStyle(
                          color: col.fg,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Text('[ cancel ]',
                        style:
                            TextStyle(color: col.fgMute, fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: TH.s14),
              Text('name',
                  style: TextStyle(color: col.fgDim, fontSize: 12)),
              const SizedBox(height: TH.s4),
              TextField(
                controller: _nameCtrl,
                autofocus: true,
                maxLength: 40,
                style: TextStyle(color: col.fg, fontSize: 14),
                inputFormatters: [
                  FilteringTextInputFormatter.deny(RegExp(r'\n')),
                ],
                decoration: InputDecoration(
                  hintText: 'group name',
                  hintStyle:
                      TextStyle(color: col.fgFaint, fontSize: 14),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: col.line2),
                    borderRadius: const BorderRadius.all(TH.r4),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: col.green),
                    borderRadius: const BorderRadius.all(TH.r4),
                  ),
                  fillColor: col.bg1,
                  filled: true,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: TH.s8, vertical: TH.s8),
                ),
                onSubmitted: (_) => _save(),
              ),
              const SizedBox(height: TH.s14),
              Text('icon (optional)',
                  style: TextStyle(color: col.fgDim, fontSize: 12)),
              const SizedBox(height: TH.s4),
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      border: Border.all(color: col.line2),
                      borderRadius: const BorderRadius.all(TH.r4),
                    ),
                    child: Center(
                      child: iconData != null
                          ? Icon(iconData, size: 18, color: col.fgDim)
                          : Icon(LucideIcons.minus,
                              size: 14, color: col.fgFaint),
                    ),
                  ),
                  const SizedBox(width: TH.s8),
                  GestureDetector(
                    onTap: () async {
                      final key = await IconPickerDialog.show(context,
                          initial: _icon);
                      if (key != null) setState(() => _icon = key);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: TH.s8, vertical: TH.s4),
                      decoration: BoxDecoration(
                        border: Border.all(color: col.line2),
                        borderRadius: const BorderRadius.all(TH.r4),
                      ),
                      child: Text('[ pick icon ]',
                          style:
                              TextStyle(color: col.fgDim, fontSize: 12)),
                    ),
                  ),
                  if (_icon != null) ...[
                    const SizedBox(width: TH.s8),
                    GestureDetector(
                      onTap: () => setState(() => _icon = null),
                      child: Text('[ clear ]',
                          style: TextStyle(
                              color: col.fgMute, fontSize: 12)),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: TH.s14),
              Text('note (optional)',
                  style: TextStyle(color: col.fgDim, fontSize: 12)),
              const SizedBox(height: TH.s4),
              TextField(
                controller: _noteCtrl,
                maxLines: 1,
                maxLength: 80,
                style: TextStyle(color: col.fg, fontSize: 13),
                inputFormatters: [
                  FilteringTextInputFormatter.deny(RegExp(r'\n')),
                ],
                decoration: InputDecoration(
                  hintText: '// optional comment under group name',
                  hintStyle:
                      TextStyle(color: col.fgFaint, fontSize: 13),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: col.line2),
                    borderRadius: const BorderRadius.all(TH.r4),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: col.green),
                    borderRadius: const BorderRadius.all(TH.r4),
                  ),
                  fillColor: col.bg1,
                  filled: true,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: TH.s8, vertical: TH.s8),
                ),
              ),
              const SizedBox(height: TH.s22),
              GestureDetector(
                onTap: _save,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: TH.s8),
                  decoration: BoxDecoration(
                    border: Border.all(color: col.green),
                    borderRadius: const BorderRadius.all(TH.r4),
                  ),
                  child: Center(
                    child: Text('[ create ]',
                        style: TextStyle(color: col.green, fontSize: 13)),
                  ),
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}
