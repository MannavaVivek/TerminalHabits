import 'package:flutter_test/flutter_test.dart';
import 'package:terminal_habits/domain/schedule.dart';
import 'package:terminal_habits/data/database.dart';

Habit _habit(String schedule) => Habit(
      id: 1,
      groupId: 'g1',
      name: 'test',
      icon: '●',
      color: 'green',
      tracking: 'checkbox',
      target: null,
      unit: null,
      schedule: schedule,
      note: null,
      sortIndex: 0,
      healthSource: null,
      createdAt: DateTime(2020),
      archivedAt: null,
    );

void main() {
  group('isHabitDueOn', () {
    // 2026-05-04 is a Monday (weekday=1 in Dart → 0 in our scheme)
    final mon = DateTime(2026, 5, 4);
    final tue = DateTime(2026, 5, 5);
    final sat = DateTime(2026, 5, 9);
    final sun = DateTime(2026, 5, 10);

    test('daily schedule is due every day', () {
      final h = _habit(dailySchedule());
      expect(isHabitDueOn(h, mon), isTrue);
      expect(isHabitDueOn(h, sat), isTrue);
    });

    test('weekday schedule is not due on Saturday', () {
      final h = _habit(weekdaySchedule());
      expect(isHabitDueOn(h, mon), isTrue);
      expect(isHabitDueOn(h, sat), isFalse);
      expect(isHabitDueOn(h, sun), isFalse);
    });

    test('weekend schedule is due only on Sat/Sun', () {
      final h = _habit(weekendSchedule());
      expect(isHabitDueOn(h, sat), isTrue);
      expect(isHabitDueOn(h, sun), isTrue);
      expect(isHabitDueOn(h, mon), isFalse);
      expect(isHabitDueOn(h, tue), isFalse);
    });

    test('custom schedule respects exact days', () {
      final h = _habit(customSchedule([0, 2, 4])); // Mon, Wed, Fri
      expect(isHabitDueOn(h, mon), isTrue);
      expect(isHabitDueOn(h, tue), isFalse);
      expect(isHabitDueOn(h, DateTime(2026, 5, 6)), isTrue); // Wed
    });
  });

  group('scheduleLabel', () {
    test('daily', () => expect(scheduleLabel(dailySchedule()), 'daily'));
    test('weekdays', () => expect(scheduleLabel(weekdaySchedule()), 'weekdays'));
    test('weekends', () => expect(scheduleLabel(weekendSchedule()), 'weekends'));
    test('custom', () => expect(scheduleLabel(customSchedule([0, 2])), 'mon, wed'));
  });
}
