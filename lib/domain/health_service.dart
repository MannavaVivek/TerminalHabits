import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:health/health.dart';

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
  static const Map<String, HealthDataType> _sourceTypes = {
    'steps': HealthDataType.STEPS,
  };

  static List<HealthDataType> _typesFor(Iterable<String> sources) {
    return [
      for (final s in sources)
        if (_sourceTypes[s] != null) _sourceTypes[s]!,
    ];
  }

  /// Returns true if Health Connect permissions have been granted for the
  /// requested [sources]. Returns false on non-Android or if the answer is
  /// unknown (treat as "not granted yet").
  static Future<bool> hasPermissions(Iterable<String> sources) async {
    if (!Platform.isAndroid) return false;
    final types = _typesFor(sources);
    if (types.isEmpty) return true;
    await _ensureConfigured();
    final granted = await _health.hasPermissions(types);
    return granted ?? false;
  }

  /// Prompts the user to grant Health Connect permissions for [sources].
  /// Returns true if all were granted.
  static Future<bool> requestPermissions(Iterable<String> sources) async {
    if (!Platform.isAndroid) return false;
    final types = _typesFor(sources);
    if (types.isEmpty) return true;
    await _ensureConfigured();
    try {
      return await _health.requestAuthorization(types);
    } catch (e) {
      debugPrint('Health requestAuthorization error: $e');
      return false;
    }
  }

  /// Reads today's accumulated value for [source] (local-day window).
  /// Returns null on any failure (no permission, Health Connect not
  /// installed, plugin error, etc.).
  static Future<int?> readTodayValue(String source) async {
    if (!Platform.isAndroid) return null;
    final type = _sourceTypes[source];
    if (type == null) return null;
    await _ensureConfigured();
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    try {
      if (source == 'steps') {
        final steps = await _health.getTotalStepsInInterval(startOfDay, now);
        return steps;
      }
      // Future sources will branch here.
      return null;
    } catch (e) {
      debugPrint('Health read $source error: $e');
      return null;
    }
  }
}
