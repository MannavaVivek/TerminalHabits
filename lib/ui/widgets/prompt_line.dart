import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class PromptLine extends StatelessWidget {
  final String user;
  final String command;

  const PromptLine({super.key, required this.user, required this.command});

  @override
  Widget build(BuildContext context) {
    final col = context.col;
    const style = TextStyle(fontSize: 14, height: 1.2);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: user,            style: style.copyWith(color: col.green)),
          TextSpan(text: '@TerminalHabits', style: style.copyWith(color: col.fgDim)),
          TextSpan(text: r'$',            style: style.copyWith(color: col.fgMute)),
          TextSpan(text: ' $command',     style: style.copyWith(color: col.fg)),
        ],
      ),
    );
  }
}
