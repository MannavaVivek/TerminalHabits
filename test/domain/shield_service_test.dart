import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terminal_habits/data/database.dart';
import 'package:terminal_habits/domain/schedule.dart';
import 'package:terminal_habits/domain/shield_service.dart';
import 'package:terminal_habits/domain/streaks.dart';

// Fixed past dates within the 90-day window (today ≈ 2026-05-16, cutoff ≈ 2026-02-15).
final _start = DateTime(2026, 4, 1); // habit start

Habit _habit({int id = 1, DateTime? startDate}) => Habit(
      id: id,
      userId: 1,
      groupId: 'g1',
      name: 'test',
      icon: '●',
      color: 'green',
      tracking: 'checkbox',
      schedule: dailySchedule(),
      sortIndex: 0,
      createdAt: startDate ?? _start,
      startDate: startDate ?? _start,
    );

Completion _done(int habitId, DateTime localDay) => Completion(
      id: 0,
      habitId: habitId,
      day: localMidnightUtc(localDay),
      value: 1.0,
      createdAt: localMidnightUtc(localDay),
    );

List<Completion> _range(int habitId, DateTime from, DateTime to) {
  final result = <Completion>[];
  var d = from;
  while (!d.isAfter(to)) {
    result.add(_done(habitId, d));
    d = DateTime(d.year, d.month, d.day + 1);
  }
  return result;
}

AppDatabase _openMemoryDb() => AppDatabase(NativeDatabase.memory());

void main() {
  // ── recomputeShieldPool ──────────────────────────────────────────────────────

  group('recomputeShieldPool', () {
    late AppDatabase db;
    setUp(() => db = _openMemoryDb());
    tearDown(() => db.close());

    test('6 consecutive completions → 0 shields (milestone not reached)', () async {
      final habit = _habit();
      await recomputeShieldPool(
        db: db,
        habits: [habit],
        completionMap: {1: _range(1, _start, DateTime(2026, 4, 6))},
        vacations: [],
        historyMap: {},
      );
      expect(await db.getAvailableShields(), 0);
    });

    test('7 consecutive completions → 1 shield', () async {
      final habit = _habit();
      await recomputeShieldPool(
        db: db,
        habits: [habit],
        completionMap: {1: _range(1, _start, DateTime(2026, 4, 7))},
        vacations: [],
        historyMap: {},
      );
      expect(await db.getAvailableShields(), 1);
    });

    test('14 consecutive completions → 2 shields', () async {
      final habit = _habit();
      await recomputeShieldPool(
        db: db,
        habits: [habit],
        completionMap: {1: _range(1, _start, DateTime(2026, 4, 14))},
        vacations: [],
        historyMap: {},
      );
      expect(await db.getAvailableShields(), 2);
    });

    test('7 done, gap on day 8, days 9-15 done → 2 shields from two fresh runs', () async {
      final habit = _habit();
      final comps = [
        ..._range(1, _start, DateTime(2026, 4, 7)),
        ..._range(1, DateTime(2026, 4, 9), DateTime(2026, 4, 15)),
      ];
      await recomputeShieldPool(
        db: db,
        habits: [habit],
        completionMap: {1: comps},
        vacations: [],
        historyMap: {},
      );
      expect(await db.getAvailableShields(), 2);
    });

    test('retroactive un-mark on day 7 reduces pool from 1 to 0', () async {
      final habit = _habit();
      // First call: 7 completions → 1 shield
      await recomputeShieldPool(
        db: db,
        habits: [habit],
        completionMap: {1: _range(1, _start, DateTime(2026, 4, 7))},
        vacations: [],
        historyMap: {},
      );
      expect(await db.getAvailableShields(), 1);

      // Simulate un-marking day 7: only 6 completions remain
      await recomputeShieldPool(
        db: db,
        habits: [habit],
        completionMap: {1: _range(1, _start, DateTime(2026, 4, 6))},
        vacations: [],
        historyMap: {},
      );
      expect(await db.getAvailableShields(), 0);
    });

    test('shielded day deducted from pool: 1 earned, 1 spent → 0 available', () async {
      final habit = _habit();
      // Pre-insert a shielded day (day 8 was spent in a prior scan)
      await db.insertDayShield(localMidnightUtc(DateTime(2026, 4, 8)));
      await recomputeShieldPool(
        db: db,
        habits: [habit],
        completionMap: {1: _range(1, _start, DateTime(2026, 4, 7))},
        vacations: [],
        historyMap: {},
      );
      // totalEarned=1, shieldedDays=1 → pool = 0
      expect(await db.getAvailableShields(), 0);
    });

    test('empty habits list → 0 shields', () async {
      await recomputeShieldPool(
        db: db,
        habits: [],
        completionMap: {},
        vacations: [],
        historyMap: {},
      );
      expect(await db.getAvailableShields(), 0);
    });
  });

  // ── runLaunchScan — spending pass ─────────────────────────────────────────────

  group('runLaunchScan — spending pass', () {
    late AppDatabase db;
    setUp(() => db = _openMemoryDb());
    tearDown(() => db.close());

    test('spends shield on a miss while streak is active', () async {
      // Habit done days 1-7 (streak=7). Day 8 missed. last_seen=day7 → scan from day8.
      // Pre-existing shield banked from a previous session.
      final habit = _habit();
      await db.setAvailableShields(1);
      await db.setSetting('last_seen_date', '2026-04-07');

      await runLaunchScan(
        db: db,
        habits: [habit],
        completionMap: {1: _range(1, _start, DateTime(2026, 4, 7))},
        vacations: [],
        historyMap: {},
      );

      final shieldedDays = await db.getAllDayShields();
      expect(shieldedDays, hasLength(1));
      expect(shieldedDays.first.day.isAtSameMomentAs(localMidnightUtc(DateTime(2026, 4, 8))), isTrue);
    });

    test('does NOT spend shield when streak is already broken before scan window', () async {
      // Two habits. Habit2 misses day 12 → streak breaks at day12.
      // last_seen=day12 → scanFrom=day13. Pre-seeded 2 shields.
      // Spending pass should not burn any shield (streak=0 at scanFrom).
      final h1 = _habit(id: 1);
      final h2 = _habit(id: 2);
      await db.setAvailableShields(2);
      await db.setSetting('last_seen_date', '2026-04-12');

      await runLaunchScan(
        db: db,
        habits: [h1, h2],
        completionMap: {
          1: _range(1, _start, DateTime(2026, 4, 12)),
          2: _range(2, _start, DateTime(2026, 4, 11)), // misses day 12
        },
        vacations: [],
        historyMap: {},
      );

      // No day shields should have been created
      expect(await db.getAllDayShields(), isEmpty);
      // Pool recomputed: milestone at day 7 → 1 earned, 0 spent → 1 available
      expect(await db.getAvailableShields(), 1);
    });

    test('shield spend stops on second consecutive miss with no shields remaining', () async {
      // Habit done days 1-7, day 8 and 9 missed. 1 shield available.
      // Day 8 should be shielded (streak alive). Day 9 miss: no shields left.
      final habit = _habit();
      await db.setAvailableShields(1);
      await db.setSetting('last_seen_date', '2026-04-07');

      await runLaunchScan(
        db: db,
        habits: [habit],
        completionMap: {1: _range(1, _start, DateTime(2026, 4, 7))},
        vacations: [],
        historyMap: {},
      );

      final shieldedDays = await db.getAllDayShields();
      // Only day 8 is shielded; day 9 miss with 0 shields → not shielded
      expect(shieldedDays, hasLength(1));
      expect(shieldedDays.first.day.isAtSameMomentAs(localMidnightUtc(DateTime(2026, 4, 8))), isTrue);
      expect(await db.getAvailableShields(), 0);
    });

    test('no shields spent when available_shields=0', () async {
      // Streak alive, miss on scan day, but 0 shields → nothing spent.
      final habit = _habit();
      await db.setAvailableShields(0);
      await db.setSetting('last_seen_date', '2026-04-07');

      await runLaunchScan(
        db: db,
        habits: [habit],
        completionMap: {1: _range(1, _start, DateTime(2026, 4, 7))},
        vacations: [],
        historyMap: {},
      );

      expect(await db.getAllDayShields(), isEmpty);
    });

    test('empty habits list returns early without error', () async {
      await runLaunchScan(
        db: db,
        habits: [],
        completionMap: {},
        vacations: [],
        historyMap: {},
      );
      expect(await db.getAvailableShields(), 0);
    });

    test('last_seen_date is set to yesterday after scan', () async {
      final habit = _habit();
      await db.setSetting('last_seen_date', '2026-04-07');

      await runLaunchScan(
        db: db,
        habits: [habit],
        completionMap: {1: _range(1, _start, DateTime(2026, 4, 7))},
        vacations: [],
        historyMap: {},
      );

      final now = DateTime.now();
      final yesterday = DateTime(now.year, now.month, now.day - 1);
      final expectedYesterday =
          '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
      expect(await db.getSetting('last_seen_date'), expectedYesterday);
    });

    // Auto-recovery: a shielded day that is now fully complete should release
    // its shield back to the pool.
    test('auto-recovery: completed shielded day returns shield to pool', () async {
      // Pre-insert a shielded day for day 8, but then mark day 8 as done.
      // Auto-recovery should remove the shield row and add 1 to the pool.
      final habit = _habit();
      await db.insertDayShield(localMidnightUtc(DateTime(2026, 4, 8)));
      await db.setAvailableShields(0);

      // Set last_seen_date = yesterday so scanFrom = today > yesterday:
      // the spending pass is skipped, only auto-recovery + recompute runs.
      final now = DateTime.now();
      final yesterday = DateTime(now.year, now.month, now.day - 1);
      final lastSeenStr =
          '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
      await db.setSetting('last_seen_date', lastSeenStr);

      // Days 1-8 all completed (user went back and filled in day 8)
      final comps = _range(1, _start, DateTime(2026, 4, 8));

      await runLaunchScan(
        db: db,
        habits: [habit],
        completionMap: {1: comps},
        vacations: [],
        historyMap: {},
      );

      // Shield row for day 8 should be removed
      expect(await db.getAllDayShields(), isEmpty);
      // Pool = 1 milestone earned (days 1-7), 0 shielded days → 1
      expect(await db.getAvailableShields(), 1);
    });
  });
}
