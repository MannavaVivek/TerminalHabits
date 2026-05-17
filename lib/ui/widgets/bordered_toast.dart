import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/tokens.dart';

void showBorderedToast(
  BuildContext context,
  String message, {
  String? undoLabel,
  VoidCallback? onUndo,
  Duration duration = const Duration(milliseconds: 2500),
}) {
  final overlay = Overlay.of(context);
  late OverlayEntry entry;

  entry = OverlayEntry(builder: (_) {
    return _BorderedToast(
      message: message,
      undoLabel: undoLabel,
      onUndo: () {
        onUndo?.call();
        entry.remove();
      },
      onDismiss: () => entry.remove(),
      duration: duration,
    );
  });

  overlay.insert(entry);
}

class _BorderedToast extends StatefulWidget {
  final String message;
  final String? undoLabel;
  final VoidCallback? onUndo;
  final VoidCallback onDismiss;
  final Duration duration;

  const _BorderedToast({
    required this.message,
    required this.onDismiss,
    required this.duration,
    this.undoLabel,
    this.onUndo,
  });

  @override
  State<_BorderedToast> createState() => _BorderedToastState();
}

class _BorderedToastState extends State<_BorderedToast> {
  @override
  void initState() {
    super.initState();
    Future.delayed(widget.duration, () {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  Widget build(BuildContext context) {
    final col = AppColors.of(context);

    return Positioned(
      bottom: 32,
      left: TH.s22,
      right: TH.s22,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: TH.s14, vertical: TH.s8),
          decoration: BoxDecoration(
            color: col.bg2,
            border: Border.all(color: col.line2),
            borderRadius: const BorderRadius.all(TH.r4),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(widget.message,
                    style: TextStyle(color: col.fg, fontSize: 12)),
              ),
              if (widget.undoLabel != null && widget.onUndo != null) ...[
                const SizedBox(width: TH.s8),
                GestureDetector(
                  onTap: widget.onUndo,
                  child: Text(
                    '[ ${widget.undoLabel} ]',
                    style: TextStyle(
                        color: col.amber,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
