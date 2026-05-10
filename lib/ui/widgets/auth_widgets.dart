import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/tokens.dart';

class AuthField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool obscure;
  final bool autofocus;
  final VoidCallback? onSubmit;

  const AuthField({
    super.key,
    required this.label,
    required this.controller,
    this.obscure = false,
    this.autofocus = false,
    this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final col = context.col;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: col.fgMute, fontSize: 11)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          obscureText: obscure,
          autofocus: autofocus,
          style: TextStyle(color: col.fg, fontSize: 13),
          onSubmitted: onSubmit != null ? (_) => onSubmit!() : null,
          decoration: InputDecoration(
            hintText: obscure ? '••••••••' : label,
            hintStyle: TextStyle(color: col.fgFaint, fontSize: 13),
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
        ),
      ],
    );
  }
}

class AuthButton extends StatelessWidget {
  final String label;
  final bool accent;
  final VoidCallback? onTap;

  const AuthButton({
    super.key,
    required this.label,
    this.accent = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final col = context.col;
    final color = onTap == null
        ? col.fgFaint
        : accent
            ? col.green
            : col.fgDim;
    return GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: color),
          borderRadius: const BorderRadius.all(TH.r4),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: TH.s14, vertical: TH.s8),
          child: Text(label, style: TextStyle(color: color, fontSize: 12)),
        ),
      ),
    );
  }
}
