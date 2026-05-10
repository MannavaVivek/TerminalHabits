import 'package:flutter/material.dart';

/// Per-theme color tokens. Provided through MaterialApp's ThemeData extensions
/// so all widgets can read [AppColors.of(context)] (or via [BuildContext.col]).
class AppColors extends ThemeExtension<AppColors> {
  final Color bg, bg1, bg2, bg3, line, line2;
  final Color fg, fgDim, fgMute, fgFaint;
  final Color green, amber, blue, purple, teal, red;

  const AppColors({
    required this.bg,
    required this.bg1,
    required this.bg2,
    required this.bg3,
    required this.line,
    required this.line2,
    required this.fg,
    required this.fgDim,
    required this.fgMute,
    required this.fgFaint,
    required this.green,
    required this.amber,
    required this.blue,
    required this.purple,
    required this.teal,
    required this.red,
  });

  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>() ?? matrix;

  @override
  AppColors copyWith({
    Color? bg, Color? bg1, Color? bg2, Color? bg3,
    Color? line, Color? line2,
    Color? fg, Color? fgDim, Color? fgMute, Color? fgFaint,
    Color? green, Color? amber, Color? blue,
    Color? purple, Color? teal, Color? red,
  }) => AppColors(
    bg: bg ?? this.bg, bg1: bg1 ?? this.bg1,
    bg2: bg2 ?? this.bg2, bg3: bg3 ?? this.bg3,
    line: line ?? this.line, line2: line2 ?? this.line2,
    fg: fg ?? this.fg, fgDim: fgDim ?? this.fgDim,
    fgMute: fgMute ?? this.fgMute, fgFaint: fgFaint ?? this.fgFaint,
    green: green ?? this.green, amber: amber ?? this.amber,
    blue: blue ?? this.blue, purple: purple ?? this.purple,
    teal: teal ?? this.teal, red: red ?? this.red,
  );

  @override
  AppColors lerp(AppColors? other, double t) => this;

  // ── Predefined themes ──────────────────────────────────────────────────────

  static const matrix = AppColors(
    bg: Color(0xFF0B1014), bg1: Color(0xFF0E1419),
    bg2: Color(0xFF131B22), bg3: Color(0xFF1A232C),
    line: Color(0xFF1D2832), line2: Color(0xFF243140),
    fg: Color(0xFFCDD6E0), fgDim: Color(0xFF8A96A3),
    fgMute: Color(0xFF5A6776), fgFaint: Color(0xFF3A4654),
    green: Color(0xFF5CE39A), amber: Color(0xFFF5B048),
    blue: Color(0xFF6CB6FF), purple: Color(0xFFC084FC),
    teal: Color(0xFF5EEAD4), red: Color(0xFFEF6B6B),
  );

  static const hacker = AppColors(
    bg: Color(0xFF000000), bg1: Color(0xFF030D06),
    bg2: Color(0xFF061209), bg3: Color(0xFF0A1A0E),
    line: Color(0xFF0D2410), line2: Color(0xFF143018),
    fg: Color(0xFF00FF41), fgDim: Color(0xFF00C032),
    fgMute: Color(0xFF007A20), fgFaint: Color(0xFF004010),
    green: Color(0xFF00FF41), amber: Color(0xFFFFFF00),
    blue: Color(0xFF00FFFF), purple: Color(0xFFFF00FF),
    teal: Color(0xFF00FF80), red: Color(0xFFFF2020),
  );

  static const nord = AppColors(
    bg: Color(0xFF2E3440), bg1: Color(0xFF3B4252),
    bg2: Color(0xFF434C5E), bg3: Color(0xFF4C566A),
    line: Color(0xFF3B4252), line2: Color(0xFF434C5E),
    fg: Color(0xFFECEFF4), fgDim: Color(0xFFD8DEE9),
    fgMute: Color(0xFF8892A0), fgFaint: Color(0xFF546070),
    green: Color(0xFFA3BE8C), amber: Color(0xFFEBCB8B),
    blue: Color(0xFF81A1C1), purple: Color(0xFFB48EAD),
    teal: Color(0xFF88C0D0), red: Color(0xFFBF616A),
  );

  static const solarized = AppColors(
    bg: Color(0xFF002B36), bg1: Color(0xFF073642),
    bg2: Color(0xFF0A3F4C), bg3: Color(0xFF0D4A57),
    line: Color(0xFF073642), line2: Color(0xFF0A3F4C),
    fg: Color(0xFFFDF6E3), fgDim: Color(0xFFEEE8D5),
    fgMute: Color(0xFF839496), fgFaint: Color(0xFF586E75),
    green: Color(0xFF859900), amber: Color(0xFFB58900),
    blue: Color(0xFF268BD2), purple: Color(0xFF6C71C4),
    teal: Color(0xFF2AA198), red: Color(0xFFDC322F),
  );

  static const monokai = AppColors(
    bg: Color(0xFF272822), bg1: Color(0xFF2E2F29),
    bg2: Color(0xFF35362F), bg3: Color(0xFF3E3F38),
    line: Color(0xFF35362F), line2: Color(0xFF45473D),
    fg: Color(0xFFF8F8F2), fgDim: Color(0xFFCCCCC0),
    fgMute: Color(0xFF75715E), fgFaint: Color(0xFF49483E),
    green: Color(0xFFA6E22E), amber: Color(0xFFE6DB74),
    blue: Color(0xFF66D9E8), purple: Color(0xFFAE81FF),
    teal: Color(0xFF66D9E8), red: Color(0xFFF92672),
  );

  static const gruvbox = AppColors(
    bg: Color(0xFF282828), bg1: Color(0xFF3C3836),
    bg2: Color(0xFF504945), bg3: Color(0xFF665C54),
    line: Color(0xFF3C3836), line2: Color(0xFF504945),
    fg: Color(0xFFEBDBB2), fgDim: Color(0xFFD5C4A1),
    fgMute: Color(0xFF928374), fgFaint: Color(0xFF5C5A53),
    green: Color(0xFFB8BB26), amber: Color(0xFFFABD2F),
    blue: Color(0xFF83A598), purple: Color(0xFFD3869B),
    teal: Color(0xFF8EC07C), red: Color(0xFFFB4934),
  );

  static const Map<String, AppColors> all = {
    'matrix': matrix,
    'hacker': hacker,
    'nord': nord,
    'solarized': solarized,
    'monokai': monokai,
    'gruvbox': gruvbox,
  };
}

extension BuildContextColorsExt on BuildContext {
  AppColors get col => AppColors.of(this);
}
