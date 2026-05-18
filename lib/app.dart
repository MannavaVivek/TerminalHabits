import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'state/providers.dart';
import 'theme/app_colors.dart';
import 'theme/theme.dart';
import 'ui/views/splash_view.dart';

double _fontScale(String size) => switch (size) {
      'sm' => 0.87,
      'lg' => 1.13,
      _ => 1.0,
    };

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeId  = ref.watch(themeIdProvider).valueOrNull  ?? 'matrix';
    final fontSize = ref.watch(fontSizeProvider).valueOrNull ?? 'md';
    final colors   = AppColors.all[themeId] ?? AppColors.matrix;
    final scale    = _fontScale(fontSize);

    return MaterialApp(
      title: 'TerminalHabits',
      theme: buildTheme(colors),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(
            textScaler: Platform.isAndroid
                ? TextScaler.noScaling
                : TextScaler.linear(scale)),
        child: child!,
      ),
      home: const SplashView(),
      debugShowCheckedModeBanner: false,
    );
  }
}
