import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/tokens.dart';

/// Thin wrapper that turns any view widget into a pushable Android page
/// with a back button at the top.
class MobileSubPage extends StatelessWidget {
  final String title;
  final Widget child;
  const MobileSubPage({required this.title, required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    final col = context.col;
    return Scaffold(
      backgroundColor: col.bg,
      body: SafeArea(
        minimum: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _BackBar(title: title, col: col),
            Container(height: 1, color: col.line),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class _BackBar extends StatelessWidget {
  final String title;
  final AppColors col;
  const _BackBar({required this.title, required this.col});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: TH.s14, horizontal: TH.s4),
        child: Row(
          children: [
            Text('‹ ',
                style: TextStyle(
                    color: col.green,
                    fontSize: 18,
                    fontWeight: FontWeight.w600)),
            Text(title,
                style: TextStyle(color: col.fg, fontSize: 14,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
