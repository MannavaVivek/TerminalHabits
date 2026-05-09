import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
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
    final iconData = lucideIconData(_icon);

    return Dialog(
      backgroundColor: TH.bg2,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.all(TH.r10)),
      child: SizedBox(
        width: 380,
        child: Padding(
          padding: const EdgeInsets.all(TH.s22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('new group',
                      style: TextStyle(
                          color: TH.fg,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Text('[ cancel ]',
                        style:
                            TextStyle(color: TH.fgMute, fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: TH.s14),
              const Text('name',
                  style: TextStyle(color: TH.fgDim, fontSize: 12)),
              const SizedBox(height: TH.s4),
              TextField(
                controller: _nameCtrl,
                autofocus: true,
                style: const TextStyle(color: TH.fg, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'group name',
                  hintStyle:
                      const TextStyle(color: TH.fgFaint, fontSize: 14),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: TH.line2),
                    borderRadius: BorderRadius.all(TH.r4),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: TH.green),
                    borderRadius: BorderRadius.all(TH.r4),
                  ),
                  fillColor: TH.bg1,
                  filled: true,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: TH.s8, vertical: TH.s8),
                ),
                onSubmitted: (_) => _save(),
              ),
              const SizedBox(height: TH.s14),
              const Text('icon (optional)',
                  style: TextStyle(color: TH.fgDim, fontSize: 12)),
              const SizedBox(height: TH.s4),
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      border: Border.all(color: TH.line2),
                      borderRadius: BorderRadius.all(TH.r4),
                    ),
                    child: Center(
                      child: iconData != null
                          ? Icon(iconData, size: 18, color: TH.fgDim)
                          : const Icon(LucideIcons.minus,
                              size: 14, color: TH.fgFaint),
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
                        border: Border.all(color: TH.line2),
                        borderRadius: BorderRadius.all(TH.r4),
                      ),
                      child: const Text('[ pick icon ]',
                          style:
                              TextStyle(color: TH.fgDim, fontSize: 12)),
                    ),
                  ),
                  if (_icon != null) ...[
                    const SizedBox(width: TH.s8),
                    GestureDetector(
                      onTap: () => setState(() => _icon = null),
                      child: const Text('[ clear ]',
                          style: TextStyle(
                              color: TH.fgMute, fontSize: 12)),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: TH.s14),
              const Text('note (optional)',
                  style: TextStyle(color: TH.fgDim, fontSize: 12)),
              const SizedBox(height: TH.s4),
              TextField(
                controller: _noteCtrl,
                style: const TextStyle(color: TH.fg, fontSize: 13),
                decoration: InputDecoration(
                  hintText: '// optional comment under group name',
                  hintStyle:
                      const TextStyle(color: TH.fgFaint, fontSize: 13),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: TH.line2),
                    borderRadius: BorderRadius.all(TH.r4),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: TH.green),
                    borderRadius: BorderRadius.all(TH.r4),
                  ),
                  fillColor: TH.bg1,
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
                    border: Border.all(color: TH.green),
                    borderRadius: BorderRadius.all(TH.r4),
                  ),
                  child: const Center(
                    child: Text('[ create ]',
                        style: TextStyle(color: TH.green, fontSize: 13)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
