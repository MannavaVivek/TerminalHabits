import 'package:flutter_test/flutter_test.dart';
import 'package:terminal_habits/domain/streaks.dart';
import 'package:terminal_habits/domain/schedule.dart';
import 'package:terminal_habits/data/database.dart';

// 2026-05-01 is a Friday.
final _epoch = DateTime(2026, 1, 1); // created date for all test habits

Habit _habit({String? schedule, DateTime? createdAt, DateTime? startDate}) =>
    Habit(
      id: 1,
      userId: 1,
      groupId: 'g1',
      name: 'test',
      icon: '●',
      color: 'green',
      tracking: 'checkbox',
      target: null,
      unit: null,
      schedule: schedule ?? dailySchedule(),
      note: null,
      sortIndex: 0,
      healthSource: null,
      createdAt: createdAt ?? _epoch,
      startDate: startDate ?? createdAt ?? _epoch,
      archivedAt: null,
    );

Completion _done(DateTime localDay, {int habitId = 1}) => Completion(
      id: 0,
      habitId: habitId,
      day: localMidnightUtc(localDay),
      value: 1.0,
      createdAt: localMidnightUtc(localDay),
    );

List<Completion> _range(DateTime from, DateTime to) {
  final result = <Completion>[];
  var d = from;
  while (!d.isAfter(to)) {
    result.add(_done(d));
    d = d.add(const Duration(days: 1));
  }
  return result;
}

void main() {
  final today = DateTime(2026, 5, 6); // Wednesday

  group('basic streaks', () {
    test('0 completions → streak 0', () {
      final r = computeStreaks(_habit(), [], today, [], const []);
      expect(r.current, 0);
      expect(r.longest, 0);
      expect(r.shields, 0);
    });

    test('checked today only → streak 1', () {
      final r = computeStreaks(_habit(), [_done(today)], today, [], const []);
      expect(r.current, 1);
      expect(r.longest, 1);
    });

    test('continuous 14-day run ending today', () {
      final from = today.subtract(const Duration(days: 13));
      final r = computeStreaks(_habit(), _range(from, today), today, [], const []);
      expect(r.current, 14);
      expect(r.longest, 14);
      expect(r.shields, 0); // Phase 8
    });

    test('missed today breaks streak (yesterday was last)', () {
      final yesterday = today.subtract(const Duration(days: 1));
      final r = computeStreaks(_habit(), [_done(yesterday)], today, [], const []);
      expect(r.current, 0);
      expect(r.longest, 1);
    });

    test('any miss in middle resets current; longest preserves prior peak', () {
      final from = today.subtract(const Duration(days: 9));
      final completions = _range(from, today)
        ..removeWhere((c) =>
            c.day == localMidnightUtc(today.subtract(const Duration(days: 6))));
      // Days -9..-7 = 3-day run. -6 missed. -5..0 = 6-day run.
      final r = computeStreaks(_habit(), completions, today, [], const []);
      expect(r.current, 6);
      expect(r.longest, 6);
    });

    test('uncheck collapses both current and longest', () {
      // 5-day run ending today, then uncheck the middle day.
      final from = today.subtract(const Duration(days: 4));
      final completions = _range(from, today)
        ..removeWhere((c) =>
            c.day == localMidnightUtc(today.subtract(const Duration(days: 2))));
      // Days -4, -3 (run 2), gap, -1, 0 (run 2).
      final r = computeStreaks(_habit(), completions, today, [], const []);
      expect(r.current, 2);
      expect(r.longest, 2);
    });
  });

  group('back-fill before createdAt', () {
    test('completions older than createdAt extend the walk', () {
      // Habit created today, but user back-fills the prior 4 days.
      final from = today.subtract(const Duration(days: 4));
      final habit = _habit(createdAt: today);
      final r = computeStreaks(habit, _range(from, today), today, [], const []);
      expect(r.current, 5);
      expect(r.longest, 5);
    });
  });

  group('start_date', () {
    test('walks from start_date when no earlier completions', () {
      // start_date 3 days ago. Completions on those 3 days. Streak = 3.
      final from = today.subtract(const Duration(days: 2));
      final habit = _habit(
        createdAt: DateTime(2026, 1, 1),
        startDate: from,
      );
      final r = computeStreaks(habit, _range(from, today), today, [], const []);
      expect(r.current, 3);
      expect(r.longest, 3);
    });

    test('back-fill before start_date still extends walk', () {
      // start_date 2 days ago, but user back-fills 5 days. Streak = 6.
      final start = today.subtract(const Duration(days: 1));
      final earliest = today.subtract(const Duration(days: 5));
      final habit = _habit(
        createdAt: DateTime(2026, 1, 1),
        startDate: start,
      );
      final r = computeStreaks(habit, _range(earliest, today), today, [], const []);
      expect(r.current, 6);
    });
  });

  group('schedule filtering', () {
    test('weekday habit — missed Saturday does not break streak', () {
      // today = Wed May 6. Mon-Tue-Wed chain; Sat May 2 / Sun May 3 not due.
      final mon = DateTime(2026, 5, 4);
      final tue = DateTime(2026, 5, 5);
      final completions = [_done(mon), _done(tue), _done(today)];
      final r = computeStreaks(
          _habit(schedule: weekdaySchedule()), completions, today, [], const []);
      expect(r.current, 3); // Mon, Tue, Wed
    });

    test('weekend habit created mid-week tracks past weekends', () {
      // today = Wed May 6. Last weekend = Sat May 2 + Sun May 3.
      // Habit created today, but user back-fills last Sat + Sun.
      final habit =
          _habit(schedule: weekendSchedule(), createdAt: today);
      final sat = DateTime(2026, 5, 2);
      final sun = DateTime(2026, 5, 3);
      final r = computeStreaks(habit, [_done(sat), _done(sun)], today, [], const []);
      expect(r.current, 2);
      expect(r.longest, 2);
    });
  });

  group('vacation', () {
    test('vacation days in middle of streak do not break it', () {
      final from = today.subtract(const Duration(days: 9));
      final vacStart = today.subtract(const Duration(days: 5));
      final vacEnd = today.subtract(const Duration(days: 3));
      final vacation = Vacation(
        id: 1,
        userId: 1,
        start: vacStart,
        end: vacEnd,
        note: null,
        active: false,
      );
      final completions = _range(from, today)
        ..removeWhere((c) {
          final d = c.day.toLocal();
          return !d.isBefore(vacStart) && !d.isAfter(vacEnd);
        });
      final r = computeStreaks(_habit(), completions, today, [vacation], const []);
      expect(r.current, 10);
    });
  });
}
