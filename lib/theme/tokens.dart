import 'package:flutter/material.dart';

// Matrix theme palette — the authoritative token set.
// Other themes override these via ThemeExtension; never hard-code these
// Color values outside the theme layer.
class TH {
  // Backgrounds
  static const bg      = Color(0xFF0B1014);
  static const bg1     = Color(0xFF0E1419);
  static const bg2     = Color(0xFF131B22);
  static const bg3     = Color(0xFF1A232C);
  static const line    = Color(0xFF1D2832);
  static const line2   = Color(0xFF243140);

  // Foregrounds
  static const fg      = Color(0xFFCDD6E0);
  static const fgDim   = Color(0xFF8A96A3);
  static const fgMute  = Color(0xFF5A6776);
  static const fgFaint = Color(0xFF3A4654);

  // Accents
  static const green   = Color(0xFF5CE39A);
  static const amber   = Color(0xFFF5B048);
  static const blue    = Color(0xFF6CB6FF);
  static const purple  = Color(0xFFC084FC);
  static const teal    = Color(0xFF5EEAD4);
  static const red     = Color(0xFFEF6B6B);

  // Spacing scale — use only these values
  static const s4  = 4.0;
  static const s8  = 8.0;
  static const s14 = 14.0;
  static const s22 = 22.0;
  static const s36 = 36.0;

  // Border radii
  static const r4  = Radius.circular(4);
  static const r6  = Radius.circular(6);
  static const r10 = Radius.circular(10);
  static const r12 = Radius.circular(12);
}
