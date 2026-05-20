import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/sync_service.dart';
import '../../domain/shield_service.dart';
import '../../domain/streaks.dart';
import '../../shortcuts/intents.dart';
import '../../state/providers.dart';
import '../../theme/app_colors.dart';
import '../inspector/inspector_pane.dart';
import '../mobile/mobile_top_bar.dart';
import '../modals/command_palette.dart';
import '../modals/edit_habit_dialog.dart';
import '../modals/future_warn_dialog.dart';
import '../modals/new_habit_dialog.dart';
import '../modals/settings_dialog.dart';
import '../nav/sidebar.dart';
import '../widgets/status_bar.dart';
import '../window/window_chrome.dart';
import 'archive_view.dart';
import 'daily_view.dart';
import 'profile_view.dart';
import 'stats_view.dart';
import 'vacation_view.dart';

class AppScaffold extends ConsumerStatefulWidget {
  const AppScaffold({super.key});

  @override
  ConsumerState<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends ConsumerState<AppScaffold> {
  bool _scanDone = false;
  Timer? _syncTimer;
  bool _pulling = false;

  void _schedulePush() {
    if (_pulling || SyncService.isPulling) return;
    if (Supabase.instance.client.auth.currentSession == null) return;
    _syncTimer?.cancel();
    _syncTimer = Timer(const Duration(seconds: 2), () {
      final db = ref.read(dbProvider);
      SyncService(db).pushAll().catchError((e) => debugPrint('pushAll error: $e'));
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  void _maybeRunScan() {
    if (_scanDone) return;
    final daily = ref.read(dailyStateProvider);
    if (!daily.hasValue) return;
    _scanDone = true;
    final db = ref.read(dbProvider);
    final habits = ref.read(habitsProvider).valueOrNull ?? [];
    final completionMap = ref.read(recentCompletionsProvider).valueOrNull ?? {};
    final vacations = ref.read(vacationsProvider).valueOrNull ?? [];
    final historyMap = ref.read(scheduleHistoryProvider).valueOrNull ?? {};
    runLaunchScan(
      db: db,
      habits: habits,
      completionMap: completionMap,
      vacations: vacations,
      historyMap: historyMap,
    ).then((_) {
      if (mounted) _recomputePool();
    }, onError: (_) {});
  }

  void _recomputePool() {
    final db = ref.read(dbProvider);
    final habits = ref.read(habitsProvider).valueOrNull ?? [];
    if (habits.isEmpty) return;
    final completionMap = ref.read(recentCompletionsProvider).valueOrNull ?? {};
    final vacations = ref.read(vacationsProvider).valueOrNull ?? [];
    final historyMap = ref.read(scheduleHistoryProvider).valueOrNull ?? {};
    recomputeShieldPool(
      db: db,
      habits: habits,
      completionMap: completionMap,
      vacations: vacations,
      historyMap: historyMap,
    ).ignore();
  }

  @override
  Widget build(BuildContext context, ) {
    // Keep settings providers alive so ref.read() in tap handlers always hits
    // a warm cached value, not AsyncValue.loading().
    ref.watch(allowFutureMarkingProvider);
    ref.watch(confirmDestructiveProvider);

    ref.listen(dailyStateProvider, (_, __) => _maybeRunScan());
    ref.listen(recentCompletionsProvider, (_, next) {
      if (next.hasValue) _recomputePool();
    });
    // Auto-push to Supabase 2s after any data change (debounced).
    ref.listen(habitsProvider, (_, __) => _schedulePush());
    ref.listen(recentCompletionsProvider, (_, __) => _schedulePush());
    ref.listen(groupsProvider, (_, __) => _schedulePush());
    ref.listen(vacationsProvider, (_, __) => _schedulePush());
    _maybeRunScan();

    final col = context.col;
    final view = ref.watch(currentViewProvider);
    final isMeta = Platform.isMacOS;

    Widget mainPane = switch (view) {
      'stats' => const StatsView(),
      'profile' => const ProfileView(),
      'vacation' => const VacationView(),
      'archive' => const ArchiveView(),
      _ => const DailyView(),
    };

    final isMobile = Platform.isAndroid;

      Widget body;
      if (isMobile) {
        body = PopScope(
          canPop: view == 'daily',
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) {
              ref.read(currentViewProvider.notifier).state = 'daily';
            }
          },
          child: _MobileBody(mainPane: mainPane),
        );
      } else {
        body = Row(
          children: [
            const Sidebar(),
            Container(width: 1, color: col.line),
            Expanded(child: mainPane),
            Container(width: 1, color: col.line),
            const InspectorPane(),
          ],
        );
      }

      Widget content = Scaffold(
        backgroundColor: col.bg,
        resizeToAvoidBottomInset: false,
        body: Column(
          children: [
            if (!isMobile) const WindowChrome(),
            Expanded(child: body),
            if (!isMobile) const StatusBar(),
          ],
        ),
      );

      if (isMobile) return content;

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
          SingleActivator(LogicalKeyboardKey.keyV,
                  meta: isMeta, control: !isMeta):
              const GoToIntent(ViewName.vacation),
          SingleActivator(LogicalKeyboardKey.keyN,
                  meta: isMeta, control: !isMeta):
              const NewHabitIntent(),
          SingleActivator(LogicalKeyboardKey.keyK,
                  meta: isMeta, control: !isMeta):
              const OpenPaletteIntent(),
          SingleActivator(LogicalKeyboardKey.comma,
                  meta: isMeta, control: !isMeta):
              const OpenSettingsIntent(),
          SingleActivator(LogicalKeyboardKey.keyR,
                  meta: isMeta, control: !isMeta):
              const SyncIntent(),
          const SingleActivator(LogicalKeyboardKey.keyJ):
              const FocusNextHabitIntent(),
          const SingleActivator(LogicalKeyboardKey.keyK):
              const FocusPrevHabitIntent(),
          const SingleActivator(LogicalKeyboardKey.space):
              const ToggleFocusedHabitIntent(),
          const SingleActivator(LogicalKeyboardKey.keyE):
              const EditFocusedHabitIntent(),
          const SingleActivator(LogicalKeyboardKey.keyA):
              const ArchiveFocusedHabitIntent(),
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
            EditFocusedHabitIntent: CallbackAction<EditFocusedHabitIntent>(
              onInvoke: (_) {
                _editFocused(context, ref);
                return null;
              },
            ),
            ArchiveFocusedHabitIntent:
                CallbackAction<ArchiveFocusedHabitIntent>(
              onInvoke: (_) {
                _archiveFocused(ref);
                return null;
              },
            ),
            SyncIntent: CallbackAction<SyncIntent>(
              onInvoke: (_) {
                _syncNow();
                return null;
              },
            ),
          },
          child: Focus(autofocus: true, child: content),
        ),
      );
  }

  void _syncNow() {
    if (Supabase.instance.client.auth.currentSession == null) return;
    final db = ref.read(dbProvider);
    _pulling = true;
    SyncService(db).pullAll()
        .catchError((Object e) { debugPrint('sync error: $e'); return false; })
        .whenComplete(() => _pulling = false);
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

  void _editFocused(BuildContext context, WidgetRef ref) {
    final focusedId = ref.read(focusedHabitIdProvider);
    if (focusedId == null) return;
    ref.read(habitsProvider).whenData((habits) {
      final habit = habits.where((h) => h.id == focusedId).firstOrNull;
      if (habit != null && context.mounted) {
        EditHabitDialog.show(context, habit);
      }
    });
  }

  Future<void> _archiveFocused(WidgetRef ref) async {
    final focusedId = ref.read(focusedHabitIdProvider);
    if (focusedId == null) return;
    await ref.read(dbProvider).archiveHabit(focusedId);
    ref.read(focusedHabitIdProvider.notifier).state = null;
  }

  Future<void> _toggleFocused(BuildContext context, WidgetRef ref) async {
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

// ── Mobile body ───────────────────────────────────────────────────────────────

class _MobileBody extends StatelessWidget {
  final Widget mainPane;
  const _MobileBody({required this.mainPane});

  @override
  Widget build(BuildContext context) {
    final col = context.col;
    return SafeArea(
      minimum: const EdgeInsets.symmetric(horizontal: 8),
      child: Stack(
        children: [
          Column(
            children: [
              const MobileTopBar(),
              Container(height: 1, color: col.line),
              Expanded(child: mainPane),
            ],
          ),
          Positioned(
            bottom: 20,
            right: 20,
            child: _MobileFab(),
          ),
        ],
      ),
    );
  }
}

class _MobileFab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(currentViewProvider);
    if (view != 'daily') return const SizedBox.shrink();

    final col = context.col;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        NewHabitDialog.show(context);
      },
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: col.bg2,
          border: Border.all(color: col.green),
          borderRadius: const BorderRadius.all(Radius.circular(6)),
        ),
        child: Center(
          child: Text(
            '[ + ]',
            style: TextStyle(
                color: col.green,
                fontSize: 13,
                fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}
