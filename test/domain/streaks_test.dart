import 'package:flutter_test/flutter_test.dart';
import 'package:terminal_habits/domain/streaks.dart';
import 'package:terminal_habits/domain/schedule.dart';
import 'package:terminal_habits/data/database.dart';

// 2026-05-01 is a Friday.
final _epoch = DateTime(2026, 1, 1); // created date for all test habits

Habit _habit({String? schedule}) => Habit(
      id: 1,
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
      createdAt: _epoch,
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
      final r = computeStreaks(_habit(), [], today, []);
      expect(r.current, 0);
      expect(r.longest, 0);
    });

    test('checked today only → streak 1', () {
      final r = computeStreaks(_habit(), [_done(today)], today, []);
      expect(r.current, 1);
    });

    test('continuous 14-day run ending today', () {
      final from = today.subtract(const Duration(days: 13));
      final r = computeStreaks(_habit(), _range(from, today), today, []);
      expect(r.current, 14);
      expect(r.longest, 14);
    });

    test('missed today breaks streak (yesterday was last)', () {
      final yesterday = today.subtract(const Duration(days: 1));
      final r = computeStreaks(_habit(), [_done(yesterday)], today, []);
      // Today is due but not completed → current streak = 0
      expect(r.current, 0);
      expect(r.longest, 1);
    });
  });

  group('shield absorption', () {
    test('14-day run with one miss on day 8 — shield absorbs', () {
      final from = today.subtract(const Duration(days: 13));
      final completions = _range(from, today)
        ..removeWhere((c) =>
            c.day == localMidnightUtc(today.subtract(const Duration(days: 6))));
      final r = computeStreaks(_habit(), completions, today, []);
      // Shield earned at day 7, absorbs the miss at day 8 → streak still 14
      expect(r.current, 14);
    });

    test('two misses in one 7-day window breaks streak on second miss', () {
      final from = today.subtract(const Duration(days: 9));
      final completions = _range(from, today)
        ..removeWhere((c) =>
            c.day == localMidnightUtc(today.subtract(const Duration(days: 3))) ||
            c.day == localMidnightUtc(today.subtract(const Duration(days: 4))));
      final r = computeStreaks(_habit(), completions, today, []);
      expect(r.current, lessThan(10));
    });
  });

  group('schedule filtering', () {
    test('weekday habit — missed Saturday does not break streak', () {
      // today = Wed May 6. Mon-Tue-Wed chain; Sat May 2 / Sun May 3 not due.
      final mon = DateTime(2026, 5, 4);
      final tue = DateTime(2026, 5, 5);
      final completions = [_done(mon), _done(tue), _done(today)];
      final r = computeStreaks(
          _habit(schedule: weekdaySchedule()), completions, today, []);
      expect(r.current, 3); // Mon, Tue, Wed
    });
  });

  group('vacation', () {
    test('vacation days in middle of streak do not break it', () {
      final from = today.subtract(const Duration(days: 9));
      // Completions for all days except vacation window
      final vacStart = today.subtract(const Duration(days: 5));
      final vacEnd = today.subtract(const Duration(days: 3));
      final vacation = Vacation(
        id: 1,
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
      final r = computeStreaks(_habit(), completions, today, [vacation]);
      expect(r.current, greaterThan(0));
      // Streak should span the vacation gap
      expect(r.current, 10); // all 10 days including vacation buffer
    });
  });
}
