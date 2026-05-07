import 'package:flutter/material.dart';
import '../../theme/tokens.dart';

// Renders the terminal prompt: vivek@TerminalHabits$ daily
// Each segment has its own color per the design spec.
class PromptLine extends StatelessWidget {
  final String user;
  final String command;

  const PromptLine({super.key, required this.user, required this.command});

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 14, height: 1.2);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: user, style: style.copyWith(color: TH.green)),
          TextSpan(text: '@TerminalHabits', style: style.copyWith(color: TH.fgDim)),
          TextSpan(text: r'$', style: style.copyWith(color: TH.fgMute)),
          TextSpan(text: ' $command', style: style.copyWith(color: TH.fg)),
        ],
      ),
    );
  }
}
