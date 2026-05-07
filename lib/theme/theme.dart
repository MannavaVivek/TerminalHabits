import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'tokens.dart';

// Instant page transitions — the app is intentionally quiet.
class NoTransitionsBuilder extends PageTransitionsBuilder {
  const NoTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}

ThemeData buildTheme() {
  final base = ThemeData.dark();
  final monoTheme = GoogleFonts.jetBrainsMonoTextTheme(base.textTheme);

  final textTheme = monoTheme.copyWith(
    bodyLarge: monoTheme.bodyLarge?.copyWith(fontSize: 14, color: TH.fg, height: 1.2),
    bodyMedium: monoTheme.bodyMedium?.copyWith(fontSize: 14, color: TH.fg, height: 1.2),
    bodySmall: monoTheme.bodySmall?.copyWith(fontSize: 12, color: TH.fgDim, height: 1.2),
    titleMedium: monoTheme.titleMedium?.copyWith(fontSize: 15, fontWeight: FontWeight.w600, color: TH.fg),
    labelSmall: monoTheme.labelSmall?.copyWith(fontSize: 11, color: TH.fgDim, height: 1.0),
    labelMedium: monoTheme.labelMedium?.copyWith(fontSize: 12, color: TH.fgDim),
  );

  return base.copyWith(
    scaffoldBackgroundColor: TH.bg,
    canvasColor: TH.bg,
    colorScheme: const ColorScheme.dark(
      surface: TH.bg,
      onSurface: TH.fg,
      primary: TH.green,
      onPrimary: TH.bg,
      error: TH.red,
      onError: TH.fg,
    ),
    textTheme: textTheme,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    hoverColor: Colors.transparent,
    focusColor: Colors.transparent,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.macOS: NoTransitionsBuilder(),
        TargetPlatform.linux: NoTransitionsBuilder(),
        TargetPlatform.android: NoTransitionsBuilder(),
      },
    ),
    dividerColor: TH.line,
    dividerTheme: const DividerThemeData(color: TH.line, thickness: 1, space: 1),
    appBarTheme: const AppBarTheme(
      backgroundColor: TH.bg1,
      foregroundColor: TH.fg,
      elevation: 0,
    ),
  );
}
