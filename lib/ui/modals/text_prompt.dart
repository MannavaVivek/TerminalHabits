import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_colors.dart';
import '../../theme/tokens.dart';

// Single-line text prompt dialog. Returns the trimmed string, or null on cancel.
Future<String?> promptText(
  BuildContext context, {
  required String title,
  required String hint,
  String initial = '',
  String saveLabel = '[ save ]',
  int maxLength = 80,
}) {
  final col = AppColors.of(context);
  final ctrl = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    barrierColor: Colors.black54,
    builder: (ctx) => Dialog(
      backgroundColor: col.bg2,
      shape:
          RoundedRectangleBorder(borderRadius: const BorderRadius.all(TH.r10)),
      child: SizedBox(
        width: 360,
        child: Padding(
          padding: const EdgeInsets.all(TH.s22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      color: col.fg,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: TH.s14),
              TextField(
                controller: ctrl,
                autofocus: true,
                maxLines: 1,
                maxLength: maxLength,
                style: TextStyle(color: col.fg, fontSize: 14),
                inputFormatters: [
                  FilteringTextInputFormatter.deny(RegExp(r'\n')),
                ],
                decoration: InputDecoration(
                  hintText: hint,
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
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: TH.s8, vertical: TH.s8),
                ),
                onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
              ),
              const SizedBox(height: TH.s14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(ctx).pop(),
                    child: Text('[ cancel ]',
                        style:
                            TextStyle(color: col.fgMute, fontSize: 12)),
                  ),
                  const SizedBox(width: TH.s14),
                  GestureDetector(
                    onTap: () =>
                        Navigator.of(ctx).pop(ctrl.text.trim()),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: TH.s14, vertical: TH.s8),
                      decoration: BoxDecoration(
                        border: Border.all(color: col.green),
                        borderRadius: const BorderRadius.all(TH.r4),
                      ),
                      child: Text(saveLabel,
                          style:
                              TextStyle(color: col.green, fontSize: 12)),
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
}
