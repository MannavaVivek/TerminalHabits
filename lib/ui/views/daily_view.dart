import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/database.dart' show Completion;
import '../../data/sync_service.dart';
import '../../domain/shield_service.dart';
import '../../domain/streaks.dart' show localMidnightUtc;
import '../../state/providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/tokens.dart';
import '../modals/new_habit_dialog.dart';
import '../widgets/habit_group.dart';
import '../widgets/week_strip.dart';

class DailyView extends ConsumerWidget {
  const DailyView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final col = context.col;
    final dailyAV = ref.watch(dailyStateProvider);
    final vacsAV = ref.watch(vacationsProvider);

    return dailyAV.when(
      loading: () => Center(
          child: Text('loading...',
              style: TextStyle(color: col.fgDim, fontSize: 13))),
      error: (e, _) => Center(
          child: Text('error: $e',
              style: TextStyle(color: col.red, fontSize: 13))),
      data: (state) {
        // Check if the selected day is in an active vacation.
        final selDay = state.today;
        final selMidnight =
            DateTime(selDay.year, selDay.month, selDay.day);
        final vacs = vacsAV.valueOrNull ?? const [];
        final activeVac = vacs.where((v) {
          if (!v.active) return false;
          final start = DateTime(v.start.toLocal().year,
              v.start.toLocal().month, v.start.toLocal().day);
          final end = DateTime(v.end.toLocal().year,
              v.end.toLocal().month, v.end.toLocal().day);
          return !selMidnight.isBefore(start) &&
              !selMidnight.isAfter(end);
        }).firstOrNull;

        Future<void> onRefresh() async {
          final db = ref.read(dbProvider);

          // Pull from Supabase if authenticated.
          // Auto-push (AppScaffold debounce) handles the outbound direction.
          if (Supabase.instance.client.auth.currentSession != null) {
            try { await SyncService(db).pullAll(); } catch (e) { debugPrint('pullAll error: $e'); }
          }

          // Recompute shield pool from fresh DB reads.
          final habits = await db.getActiveHabits(1);
          if (habits.isEmpty) return;
          final vacations = await db.getVacations(1);
          final sinceUtc = localMidnightUtc(
              DateTime.now().subtract(const Duration(days: 90)));
          final recentList = await db.getRecentCompletionsList(sinceUtc);
          final completionMap = <int, List<Completion>>{};
          for (final c in recentList) (completionMap[c.habitId] ??= []).add(c);
          final historyMap = await db.getAllScheduleHistory();
          await recomputeShieldPool(
            db: db,
            habits: habits,
            completionMap: completionMap,
            vacations: vacations,
            historyMap: historyMap,
          );
        }

        Widget body;
        if (activeVac != null) {
          body = _VacationActiveMessage(vacation: activeVac);
        } else if (state.groups.isEmpty) {
          body = _EmptyDay(selectedDay: state.today);
        } else {
          body = ListView.builder(
            padding: const EdgeInsets.only(bottom: 88), // clear the FAB
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: state.groups.length + 1,
            itemBuilder: (context, i) {
              if (i == state.groups.length) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(
                      TH.s14, TH.s14, TH.s14, TH.s8),
                  child: _AddHabitButton(defaultStartDate: state.today),
                );
              }
              return HabitGroupWidget(dailyGroup: state.groups[i]);
            },
          );
        }

        if (Platform.isAndroid) {
          body = RefreshIndicator(
            color: col.green,
            backgroundColor: col.bg2,
            onRefresh: onRefresh,
            child: body is _EmptyDay || body is _VacationActiveMessage
                ? SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: SizedBox(
                      height: MediaQuery.of(context).size.height * 0.6,
                      child: body,
                    ),
                  )
                : body,
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  TH.s14, TH.s14, TH.s14, 0),
              child: _DailyHeader(state: state),
            ),
            const SizedBox(height: TH.s14),
            const WeekStrip(),
            const SizedBox(height: TH.s14),
            Expanded(child: body),
          ],
        );
      },
    );
  }
}

class _VacationActiveMessage extends StatelessWidget {
  final dynamic vacation; // Vacation type
  const _VacationActiveMessage({required this.vacation});

  String _fmt(DateTime d) {
    final local = d.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final col = context.col;
    final start = _fmt(vacation.start as DateTime);
    final end = _fmt(vacation.end as DateTime);
    return Padding(
      padding: const EdgeInsets.all(TH.s22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('vacation active.',
              style: TextStyle(
                  color: col.amber,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: TH.s8),
          Text('$start → $end',
              style: TextStyle(color: col.fgDim, fontSize: 13)),
          const SizedBox(height: TH.s14),
          Text(
            '// tracking resumes when you\'re back.',
            style: TextStyle(color: col.fgMute, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _AddHabitButton extends StatelessWidget {
  final DateTime defaultStartDate;
  const _AddHabitButton({required this.defaultStartDate});

  @override
  Widget build(BuildContext context) {
    final col = context.col;
    return GestureDetector(
      onTap: () => NewHabitDialog.show(
        context,
        defaultStartDate: defaultStartDate,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: TH.s8),
        decoration: BoxDecoration(
          border: Border.all(color: col.line2),
          borderRadius: const BorderRadius.all(TH.r4),
        ),
        child: Center(
          child: Text('[ + new habit ]',
              style: TextStyle(color: col.fgDim, fontSize: 12)),
        ),
      ),
    );
  }
}

class _DailyHeader extends ConsumerWidget {
  final DailyState state;
  const _DailyHeader({required this.state});

  static const _days = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday',
    'Friday', 'Saturday', 'Sunday',
  ];
  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final col = context.col;
    final userName = ref.watch(userNameProvider);
    final day = state.today;
    final dateLine =
        '${_days[day.weekday - 1]}, ${_months[day.month - 1]} ${day.day} ${day.year}';
    final n = state.totalCompletionsAllTime;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(TextSpan(children: [
          TextSpan(
            text: userName,
            style: TextStyle(color: col.green, fontSize: 13),
          ),
          TextSpan(
              text: '@TerminalHabits ',
              style: TextStyle(color: col.fgDim, fontSize: 13)),
          TextSpan(
              text: '\$ ',
              style: TextStyle(color: col.fgMute, fontSize: 13)),
          TextSpan(
              text: 'daily',
              style: TextStyle(color: col.fg, fontSize: 13)),
        ])),
        const SizedBox(height: 4),
        Text(
          _completionComment(n),
          style: TextStyle(color: col.fgMute, fontSize: 12),
        ),
        const SizedBox(height: TH.s8),
        Row(
          children: [
            Icon(LucideIcons.calendar, size: 13, color: col.fgDim),
            const SizedBox(width: TH.s8),
            Text(dateLine,
                style: TextStyle(color: col.fg, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Icon(LucideIcons.flame, size: 13,
                color: state.overallStreak.todayAtRisk ? col.fgMute : col.amber),
            const SizedBox(width: 4),
            Text(
              '${state.overallStreak.displayStreak} days',
              style: TextStyle(
                fontSize: 12,
                color: state.overallStreak.todayAtRisk ? col.fgMute : col.amber,
              ),
            ),
            const SizedBox(width: TH.s8),
            Text('*', style: TextStyle(color: col.fgMute, fontSize: 12)),
            const SizedBox(width: TH.s8),
            Icon(LucideIcons.shield, size: 12, color: col.blue),
            const SizedBox(width: 4),
            Text('${state.availableShields}',
                style: TextStyle(color: col.blue, fontSize: 12)),
          ],
        ),
      ],
    );
  }
}

String _completionComment(int n) {
  if (n == 0) return '// just getting started.';
  if (n < 5) return '// $n completions. the first few stick. keep going.';
  if (n < 25) return '// $n completions. building habit-mass.';
  if (n < 50) {
    return "// $n completions. you're past the dabbling phase.";
  }
  if (n < 100) {
    return '// $n completions. the data is starting to mean something.';
  }
  if (n < 250) return '// $n completions. reps compound.';
  if (n < 500) return '// $n completions. the boring middle.';
  return '// $n completions. operator-level consistency.';
}

class _EmptyDay extends StatelessWidget {
  final DateTime selectedDay;
  const _EmptyDay({required this.selectedDay});

  @override
  Widget build(BuildContext context) {
    final col = context.col;
    final isMobile = Platform.isAndroid;
    final hint = isMobile
        ? 'tap [ + ] to add a habit.'
        : 'press ⌘N to add a habit.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isMobile)
          Padding(
            padding:
                const EdgeInsets.fromLTRB(TH.s14, 0, TH.s14, TH.s14),
            child: _AddHabitButton(defaultStartDate: selectedDay),
          ),
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('no habits here.',
                    style: TextStyle(color: col.fgDim, fontSize: 14)),
                const SizedBox(height: 8),
                Text(hint,
                    style: TextStyle(
                        color: col.fgFaint, fontSize: 13)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
