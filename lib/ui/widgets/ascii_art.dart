import 'package:flutter/material.dart';

// Renders a multi-line ASCII string in monospace with line-height 1.0
// so the art stays on a strict grid.
class AsciiArt extends StatelessWidget {
  final String text;
  final double fontSize;
  final Color color;

  const AsciiArt(
    this.text, {
    super.key,
    this.fontSize = 11,
    this.color = const Color(0xFF5CE39A), // TH.green fallback
  });

  @override
  Widget build(BuildContext context) {
    return SelectableText(
      text,
      style: TextStyle(
        fontFamily: 'JetBrains Mono',
        fontSize: fontSize,
        color: color,
        height: 1.0,
        letterSpacing: 0,
      ),
    );
  }
}
