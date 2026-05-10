import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

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

ThemeData buildTheme(AppColors col) {
  final base = ThemeData.dark();
  final monoTheme = GoogleFonts.jetBrainsMonoTextTheme(base.textTheme);

  final textTheme = monoTheme.copyWith(
    bodyLarge:   monoTheme.bodyLarge?.copyWith(fontSize: 14, color: col.fg,     height: 1.2),
    bodyMedium:  monoTheme.bodyMedium?.copyWith(fontSize: 14, color: col.fg,    height: 1.2),
    bodySmall:   monoTheme.bodySmall?.copyWith(fontSize: 12, color: col.fgDim,  height: 1.2),
    titleMedium: monoTheme.titleMedium?.copyWith(fontSize: 15, fontWeight: FontWeight.w600, color: col.fg),
    labelSmall:  monoTheme.labelSmall?.copyWith(fontSize: 11, color: col.fgDim, height: 1.0),
    labelMedium: monoTheme.labelMedium?.copyWith(fontSize: 12, color: col.fgDim),
  );

  return base.copyWith(
    extensions: [col],
    scaffoldBackgroundColor: col.bg,
    canvasColor: col.bg,
    colorScheme: ColorScheme.dark(
      surface: col.bg,
      onSurface: col.fg,
      primary: col.green,
      onPrimary: col.bg,
      error: col.red,
      onError: col.fg,
    ),
    textTheme: textTheme,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    hoverColor: Colors.transparent,
    focusColor: Colors.transparent,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.macOS:   NoTransitionsBuilder(),
        TargetPlatform.linux:   NoTransitionsBuilder(),
        TargetPlatform.android: NoTransitionsBuilder(),
      },
    ),
    dividerColor: col.line,
    dividerTheme: DividerThemeData(color: col.line, thickness: 1, space: 1),
    appBarTheme: AppBarTheme(
      backgroundColor: col.bg1,
      foregroundColor: col.fg,
      elevation: 0,
    ),
  );
}
