import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/database.dart';
import '../domain/schedule.dart';
import '../domain/streaks.dart';

// ── Database ──────────────────────────────────────────────────────────────────

final dbProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('dbProvider must be overridden in main.dart'),
);

// ── Streams ───────────────────────────────────────────────────────────────────

final groupsProvider = StreamProvider<List<Group>>(
  (ref) => ref.watch(dbProvider).watchGroups(),
);

final habitsProvider = StreamProvider<List<Habit>>(
  (ref) => ref.watch(dbProvider).watchActiveHabits(),
);

final todayCompletionsProvider = StreamProvider<List<Completion>>((ref) {
  final todayUtc = localMidnightUtc(DateTime.now());
  return ref.watch(dbProvider).watchCompletionsForDay(todayUtc);
});

final recentCompletionsProvider =
    StreamProvider<Map<int, List<Completion>>>((ref) {
  final sinceUtc = localMidnightUtc(
    DateTime.now().subtract(const Duration(days: 90)),
  );
  return ref.watch(dbProvider).watchRecentCompletions(sinceUtc).map((list) {
    final map = <int, List<Completion>>{};
    for (final c in list) (map[c.habitId] ??= []).add(c);
    return map;
  });
});

final vacationsProvider = StreamProvider<List<Vacation>>(
  (ref) => ref.watch(dbProvider).watchVacations(),
);

// ── View state ────────────────────────────────────────────────────────────────

final currentViewProvider = StateProvider<String>((ref) => 'daily');
final focusedHabitIdProvider = StateProvider<int?>((ref) => null);

// ── Domain models ─────────────────────────────────────────────────────────────

class DailyHabit {
  final Habit habit;
  final Completion? todayCompletion;
  final StreakResult streaks;

  const DailyHabit({
    required this.habit,
    required this.todayCompletion,
    required this.streaks,
  });

  bool get isDoneToday => todayCompletion != null;
}

class DailyGroup {
  final Group group;
  final List<DailyHabit> habits;

  const DailyGroup({required this.group, required this.habits});

  int get doneCount => habits.where((h) => h.isDoneToday).length;
}

class DailyState {
  final List<DailyGroup> groups;
  final DateTime today;

  const DailyState({required this.groups, required this.today});

  int get totalDone => groups.fold(0, (sum, g) => sum + g.doneCount);
  int get totalHabits => groups.fold(0, (sum, g) => sum + g.habits.length);
}

// ── Computed daily state ──────────────────────────────────────────────────────

final dailyStateProvider = Provider<AsyncValue<DailyState>>((ref) {
  final groupsAV = ref.watch(groupsProvider);
  final habitsAV = ref.watch(habitsProvider);
  final todayAV = ref.watch(todayCompletionsProvider);
  final recentAV = ref.watch(recentCompletionsProvider);
  final vacAV = ref.watch(vacationsProvider);

  for (final av in [groupsAV, habitsAV, todayAV, recentAV, vacAV]) {
    if (av.isLoading) return const AsyncValue.loading();
    if (av.hasError) return AsyncValue.error(av.error!, av.stackTrace!);
  }

  final groups = groupsAV.requireValue;
  final habits = habitsAV.requireValue;
  final todayComps = todayAV.requireValue;
  final recentMap = recentAV.requireValue;
  final vacList = vacAV.requireValue;
  final today = DateTime.now();
  final todayCompMap = {for (final c in todayComps) c.habitId: c};

  final dailyGroups = groups
      .map((group) {
        final groupHabits = habits
            .where((h) => h.groupId == group.id)
            .map((h) => DailyHabit(
                  habit: h,
                  todayCompletion: todayCompMap[h.id],
                  streaks: computeStreaks(
                      h, recentMap[h.id] ?? [], today, vacList),
                ))
            .toList();
        return DailyGroup(group: group, habits: groupHabits);
      })
      .where((g) => g.habits.isNotEmpty)
      .toList();

  return AsyncValue.data(DailyState(groups: dailyGroups, today: today));
});

