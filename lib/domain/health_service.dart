import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:health/health.dart';

/// UI-facing config for each health source: how to label the goal field,
/// what hint to show, and how to convert the user-entered goal into the
/// integer value we store internally (the same unit `readTodayValue`
/// returns, so sync compares apples-to-apples).
class HealthSourceConfig {
  final String key;             // 'steps', 'sleep', 'exercise'
  final String goalUnitLabel;   // 'steps', 'hours', 'minutes'
  final String hint;            // suggested goal in the UI
  final int Function(int) goalToInternal; // user-input → stored int
  final int Function(int) internalToGoal; // stored int → display value
  final String storedUnit;      // value placed in habits.unit
  const HealthSourceConfig({
    required this.key,
    required this.goalUnitLabel,
    required this.hint,
    required this.goalToInternal,
    required this.internalToGoal,
    required this.storedUnit,
  });
}

const Map<String, HealthSourceConfig> kHealthSources = {
  'steps': HealthSourceConfig(
    key: 'steps',
    goalUnitLabel: 'steps',
    hint: '8000',
    goalToInternal: _identity,
    internalToGoal: _identity,
    storedUnit: 'steps',
  ),
  'sleep': HealthSourceConfig(
    key: 'sleep',
    goalUnitLabel: 'hours',
    hint: '7',
    goalToInternal: _hoursToMinutes,
    internalToGoal: _minutesToHours,
    storedUnit: 'min',
  ),
  'exercise': HealthSourceConfig(
    key: 'exercise',
    goalUnitLabel: 'minutes',
    hint: '30',
    goalToInternal: _identity,
    internalToGoal: _identity,
    storedUnit: 'min',
  ),
};

int _identity(int v) => v;
int _hoursToMinutes(int h) => h * 60;
int _minutesToHours(int m) => m ~/ 60;

/// Thin wrapper around the `health` plugin. Provides:
///   - permission checks/requests for the metrics we care about
///   - read-only fetch of today's value for a given health source
///
/// Android only — the plugin is a no-op stub on other platforms. The
/// public methods return `null` / `false` on non-Android.
class HealthService {
  static final Health _health = Health();
  static bool _configured = false;

  static Future<void> _ensureConfigured() async {
    if (_configured) return;
    if (!Platform.isAndroid) return;
    await _health.configure();
    _configured = true;
  }

  /// Health Connect types we read. Add new entries here as we add sources.
  /// `sleep` and `exercise` return session records (start + end timestamps);
  /// we sum their durations in minutes.
  static const Map<String, HealthDataType> _sourceTypes = {
    'steps': HealthDataType.STEPS,
    'sleep': HealthDataType.SLEEP_SESSION,
    'exercise': HealthDataType.WORKOUT,
  };

  static List<HealthDataType> _typesFor(Iterable<String> sources) {
    return [
      for (final s in sources)
        if (_sourceTypes[s] != null) _sourceTypes[s]!,
    ];
  }

  /// Returns true if Health Connect READ permissions have been granted for
  /// the requested [sources]. Returns false on non-Android or if unknown.
  static Future<bool> hasPermissions(Iterable<String> sources) async {
    if (!Platform.isAndroid) return false;
    final types = _typesFor(sources);
    if (types.isEmpty) return true;
    await _ensureConfigured();
    final perms = List<HealthDataAccess>.filled(types.length, HealthDataAccess.READ);
    final granted = await _health.hasPermissions(types, permissions: perms);
    return granted ?? false;
  }

  /// Asks the OS to prompt for Health Connect permissions on [sources].
  /// The plugin's `requestAuthorization` returns false when no UI was shown
  /// (e.g. the user already granted/denied in a prior session), so we also
  /// re-check `hasPermissions` afterward and trust the more-recent result.
  static Future<bool> requestPermissions(Iterable<String> sources) async {
    if (!Platform.isAndroid) return false;
    final types = _typesFor(sources);
    if (types.isEmpty) return true;
    await _ensureConfigured();
    final perms = List<HealthDataAccess>.filled(types.length, HealthDataAccess.READ);
    if (await hasPermissions(sources)) return true;
    try {
      final reqResult = await _health.requestAuthorization(types, permissions: perms);
      if (reqResult) return true;
    } catch (e) {
      debugPrint('Health requestAuthorization error: $e');
    }
    // Re-check — Health Connect may have granted silently or the user
    // returned from a manual flow with permission now in place.
    return hasPermissions(sources);
  }

  /// Reads today's accumulated value for [source] (local-day window).
  /// Returns null on any failure (no permission, Health Connect not
  /// installed, plugin error, etc.).
  ///
  /// Units returned:
  ///   - steps    → step count (sum of numeric data points)
  ///   - sleep    → minutes (sum of session durations whose wake-up is today)
  ///   - exercise → minutes (sum of session durations whose end is today)
  static Future<int?> readTodayValue(String source) async {
    if (!Platform.isAndroid) return null;
    final type = _sourceTypes[source];
    if (type == null) return null;
    await _ensureConfigured();
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    // Sleep windows usually start the previous evening, so query 24h back
    // and let the session-end filter attribute them to today.
    final queryStart =
        source == 'sleep' ? startOfDay.subtract(const Duration(days: 1))
                          : startOfDay;
    final endOfDay =
        DateTime(now.year, now.month, now.day, 23, 59, 59);
    try {
      final data = await _health.getHealthDataFromTypes(
        startTime: queryStart,
        endTime: now,
        types: [type],
      );
      if (data.isEmpty) {
        debugPrint('Health $source: no data points (window '
            '${queryStart.toIso8601String()} → ${now.toIso8601String()})');
        return 0;
      }
      int total;
      if (source == 'sleep' || source == 'exercise') {
        // Sum durations (in minutes) of sessions whose end falls in today's
        // local-day window. Health Connect can return sessions started
        // yesterday (sleep especially); attribute them to wake-up day.
        total = 0;
        for (final p in data) {
          if (p.dateTo.isBefore(startOfDay) || p.dateTo.isAfter(endOfDay)) {
            continue;
          }
          total += p.dateTo.difference(p.dateFrom).inMinutes;
        }
      } else {
        // Numeric (steps, etc.) — sum the values.
        total = 0;
        for (final p in data) {
          final v = p.value;
          if (v is NumericHealthValue) {
            total += v.numericValue.toInt();
          }
        }
      }
      debugPrint(
          'Health $source: ${data.length} point(s), total = $total');
      return total;
    } catch (e) {
      debugPrint('Health read $source error: $e');
      return null;
    }
  }

  /// Returns a one-line human-readable diagnostic for [source]. Useful for
  /// in-app debugging when auto-completion isn't firing as expected.
  static Future<String> diagnose(String source) async {
    if (!Platform.isAndroid) return 'not android — health connect unavailable';
    final type = _sourceTypes[source];
    if (type == null) return 'unknown source "$source"';
    final hasPerm = await hasPermissions([source]);
    final value = await readTodayValue(source);
    final unit = switch (source) {
      'steps' => '',
      'sleep' => ' min (sleep, attributed to today)',
      'exercise' => ' min (exercise sessions ending today)',
      _ => '',
    };
    final dataLine = value == null
        ? 'read error (see debug log)'
        : 'today: $value$unit';
    return 'permission: ${hasPerm ? "granted" : "not granted"}\n$dataLine';
  }
}
