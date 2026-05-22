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
