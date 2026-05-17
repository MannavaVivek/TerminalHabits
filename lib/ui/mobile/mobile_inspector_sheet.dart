import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/tokens.dart';
import '../inspector/inspector_pane.dart';

Future<void> showMobileInspector(BuildContext context) {
  final col = AppColors.of(context);
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: col.bg2,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
    ),
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.4,
      minChildSize: 0.2,
      maxChildSize: 0.9,
      expand: false,
      builder: (ctx, scrollController) => Column(
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.symmetric(vertical: TH.s8),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: col.line2,
                borderRadius: const BorderRadius.all(Radius.circular(2)),
              ),
            ),
          ),
          Container(height: 1, color: col.line),
          // Reuse desktop InspectorPane — it's a ConsumerWidget that watches
          // the same providers, so content is identical to the desktop pane.
          const Expanded(child: InspectorPane()),
        ],
      ),
    ),
  );
}
