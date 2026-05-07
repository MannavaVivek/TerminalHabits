import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme/theme.dart';
import 'ui/views/splash_view.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'TerminalHabits',
      theme: buildTheme(),
      home: const SplashView(),
      debugShowCheckedModeBanner: false,
    );
  }
}
