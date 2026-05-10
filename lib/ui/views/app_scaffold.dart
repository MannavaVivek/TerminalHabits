import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/streaks.dart';
import '../../shortcuts/intents.dart';
import '../../state/providers.dart';
import '../../theme/app_colors.dart';
import '../inspector/inspector_pane.dart';
import '../modals/command_palette.dart';
import '../modals/future_warn_dialog.dart';
import '../modals/new_habit_dialog.dart';
import '../modals/settings_dialog.dart';
import '../nav/sidebar.dart';
import '../widgets/status_bar.dart';
import '../window/window_chrome.dart';
import 'daily_view.dart';
import 'stats_view.dart';

class AppScaffold extends ConsumerWidget {
  const AppScaffold({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final col = context.col;
    final view = ref.watch(currentViewProvider);
    final isDesktop = Platform.isMacOS || Platform.isLinux;
    final isMeta = Platform.isMacOS;

    Widget mainPane = switch (view) {
      'stats' => const StatsView(),
      _ => const DailyView(),
    };

    Widget body = isDesktop
        ? Row(
            children: [
              const Sidebar(),
              Container(width: 1, color: col.line),
              Expanded(child: mainPane),
              Container(width: 1, color: col.line),
              const InspectorPane(),
            ],
          )
        : mainPane;

    Widget content = Scaffold(
      backgroundColor: col.bg,
      body: Column(
        children: [
          if (isDesktop) const WindowChrome(),
          Expanded(child: body),
          const StatusBar(),
        ],
      ),
    );

    if (!isDesktop) return content;

    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.digit1,
                meta: isMeta, control: !isMeta):
            const GoToIntent(ViewName.daily),
        SingleActivator(LogicalKeyboardKey.digit2,
                meta: isMeta, control: !isMeta):
            const GoToIntent(ViewName.stats),

        SingleActivator(LogicalKeyboardKey.keyN,
                meta: isMeta, control: !isMeta):
            const NewHabitIntent(),
        SingleActivator(LogicalKeyboardKey.keyK,
                meta: isMeta, control: !isMeta):
            const OpenPaletteIntent(),
        SingleActivator(LogicalKeyboardKey.comma,
                meta: isMeta, control: !isMeta):
            const OpenSettingsIntent(),
        const SingleActivator(LogicalKeyboardKey.keyJ):
            const FocusNextHabitIntent(),
        const SingleActivator(LogicalKeyboardKey.keyK):
            const FocusPrevHabitIntent(),
        const SingleActivator(LogicalKeyboardKey.space):
            const ToggleFocusedHabitIntent(),
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
          OpenPaletteIntent: CallbackAction<OpenPaletteIntent>(
            onInvoke: (_) {
              CommandPalette.show(context);
              return null;
            },
          ),
          OpenSettingsIntent: CallbackAction<OpenSettingsIntent>(
            onInvoke: (_) {
              SettingsDialog.show(context);
              return null;
            },
          ),
          FocusNextHabitIntent: CallbackAction<FocusNextHabitIntent>(
            onInvoke: (_) {
              _moveFocus(ref, 1);
              return null;
            },
          ),
          FocusPrevHabitIntent: CallbackAction<FocusPrevHabitIntent>(
            onInvoke: (_) {
              _moveFocus(ref, -1);
              return null;
            },
          ),
          ToggleFocusedHabitIntent:
              CallbackAction<ToggleFocusedHabitIntent>(
            onInvoke: (_) {
              _toggleFocused(context, ref);
              return null;
            },
          ),
        },
        child: Focus(autofocus: true, child: content),
      ),
    );
  }

  void _moveFocus(WidgetRef ref, int delta) {
    ref.read(dailyStateProvider).whenData((state) {
      final flat = state.groups.expand((g) => g.habits).toList();
      if (flat.isEmpty) return;
      final focusedId = ref.read(focusedHabitIdProvider);
      final idx = flat.indexWhere((h) => h.habit.id == focusedId);
      final nextIdx = (idx + delta).clamp(0, flat.length - 1);
      ref.read(focusedHabitIdProvider.notifier).state =
          flat[nextIdx].habit.id;
    });
  }

  Future<void> _toggleFocused(
      BuildContext context, WidgetRef ref) async {
    final focusedId = ref.read(focusedHabitIdProvider);
    if (focusedId == null) return;

    final selectedDay = ref.read(selectedDayProvider);
    final now = DateTime.now();
    final selDate =
        DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
    final today = DateTime(now.year, now.month, now.day);

    if (selDate.isAfter(today)) {
      final allowFuture =
          ref.read(allowFutureMarkingProvider).valueOrNull ?? false;
      if (!allowFuture) {
        await confirmFutureToggle(context);
        return;
      }
    }

    final db = ref.read(dbProvider);
    final dayUtc = localMidnightUtc(selectedDay);
    await db.toggleCompletion(focusedId, dayUtc);
  }
}
