import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shortcuts/intents.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../inspector/inspector_pane.dart';
import '../modals/new_habit_dialog.dart';
import '../nav/sidebar.dart';
import '../widgets/status_bar.dart';
import '../window/window_chrome.dart';
import 'daily_view.dart';
import 'profile_view.dart';
import 'stats_view.dart';

class AppScaffold extends ConsumerWidget {
  const AppScaffold({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(currentViewProvider);
    final isDesktop = Platform.isMacOS || Platform.isLinux;
    final isMeta = Platform.isMacOS;

    Widget mainPane = switch (view) {
      'stats' => const StatsView(),
      'profile' => const ProfileView(),
      _ => const DailyView(),
    };

    Widget body = isDesktop
        ? Row(
            children: [
              const Sidebar(),
              Container(width: 1, color: TH.line),
              Expanded(child: mainPane),
              Container(width: 1, color: TH.line),
              const InspectorPane(),
            ],
          )
        : mainPane;

    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.digit1,
                meta: isMeta, control: !isMeta):
            const GoToIntent(ViewName.daily),
        SingleActivator(LogicalKeyboardKey.digit2,
                meta: isMeta, control: !isMeta):
            const GoToIntent(ViewName.stats),
        SingleActivator(LogicalKeyboardKey.digit3,
                meta: isMeta, control: !isMeta):
            const GoToIntent(ViewName.profile),
        SingleActivator(LogicalKeyboardKey.keyN,
                meta: isMeta, control: !isMeta):
            const NewHabitIntent(),
      },
      child: Actions(
        actions: {
          GoToIntent: CallbackAction<GoToIntent>(
            onInvoke: (intent) {
              ref.read(currentViewProvider.notifier).state =
                  intent.view.name;
              return null;
            },
          ),
          NewHabitIntent: CallbackAction<NewHabitIntent>(
            onInvoke: (_) {
              NewHabitDialog.show(context);
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            backgroundColor: TH.bg,
            body: Column(
              children: [
                if (isDesktop) const WindowChrome(),
                Expanded(child: body),
                const StatusBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
