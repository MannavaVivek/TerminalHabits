# Phase 8 — Smoke log

**Completed:** 2026-05-17  
**Phase:** Per-day shield system

---

## Quality gates

| Gate | Status |
|------|--------|
| `flutter analyze --no-fatal-infos` clean | ✓ 0 errors, 0 warnings |
| `flutter test` green | ✓ 17 tests |
| Manual smoke (below) | ✓ |
| New deps with Decision Log | none |
| Spec files updated | ✓ roadmap.md updated |

---

## New files

- `lib/domain/shield_service.dart` — `runLaunchScan` (spending pass) and `recomputeShieldPool` (earning pass).
- `test/domain/shield_service_test.dart` — 17 unit tests covering both passes, auto-recovery, `createdAt` gate, and edge cases.

---

## Modified files

### `lib/data/database.dart`
- DB version bumped; migration adds `day_shields` table (`id`, `day UNIQUE`, `applied_at`).
- New settings rows seeded: `available_shields` (default `'0'`), `shieldEarnInterval` (default `'7'`), `last_seen_date` (default `''`).
- New queries: `insertDayShield`, `deleteDayShield`, `getAllDayShields`, `watchDayShields`, `getAvailableShields`, `setAvailableShields`.

### `lib/domain/shield_service.dart`
- **`runLaunchScan`**: two-pass once-per-launch function.
  - Pre-pass auto-recovery: shielded days that are now fully complete have their row removed and pool incremented before spending starts.
  - Pass 1 spending: walks `last_seen_date+1 … yesterday` chronologically. Guards: `spendingStreak > 0` (overall streak must be alive), `shields > 0`, day must be `≥ spendingStart` (`max(createdAt)` across habits — prevents retroactive spending on backdated history).
  - Pass 2 earning: delegates to `recomputeShieldPool`.
  - Sets `last_seen_date = yesterday` after every scan.
- **`recomputeShieldPool`**: session-time pool sync (safe to call after every completion write).
  - Auto-recovery: removes shield rows for days now fully complete.
  - Recomputes `available_shields = totalMilestonesEarned − shieldedDaysCount`.
  - `_totalMilestonesEarned`: walks from earliest habit start (capped at 90 days) through yesterday, counting milestone crossings every `shieldEarnInterval` days; streak resets restart the per-run milestone counter independently.
  - Both entry points clean up orphaned shield rows and reset `available_shields = 0` when `habits.isEmpty`.
- **Timezone safety**: all DB-returned `DateTime` values normalised with `.toUtc()` before Set membership checks (`DateTime ==` checks the `isUtc` flag). `_dayFullyComplete` re-derives UTC via `localMidnightUtc(d)` to guarantee `isUtc=true` on both sides of the comparison.

### `lib/state/providers.dart`
- `dayShieldsProvider`: stream of `Set<DateTime>` (UTC) from `watchDayShields`; Drift returns local datetimes — `.toUtc()` applied on each element.
- `availableShieldsProvider`: stream of `int` from `watchSetting('available_shields')`.
- `DailyState` gained `availableShields` and `shieldedDays` fields.
- `weeklyRatios` / `DayRatio`: `shielded` flag added; only set when `due > 0 && shieldedDays.contains(dayUtc)` — prevents ghost blue bars when habits are deleted.

### `lib/ui/views/app_scaffold.dart`
- `_maybeRunScan`: calls `runLaunchScan` once after `dailyStateProvider` emits its first value; then calls `_recomputePool()` in `.then()` to correct any pool staleness if completions changed while the scan ran.
- `_recomputePool`: calls `recomputeShieldPool` on every `recentCompletionsProvider` change.
- `ref.watch(allowFutureMarkingProvider)` and `ref.watch(confirmDestructiveProvider)` added to `build()` to keep these `StreamProvider`s alive at all times. Without this, they were disposed after the settings dialog closed; the next `ref.read` in a tap handler found `AsyncValue.loading()` → `valueOrNull = null` → defaults to false, making "allow future marking" appear to not persist.

### `lib/ui/widgets/habit_row.dart`
- On a shielded day where the specific habit was not completed, a `LucideIcons.shield` icon (blue) is shown in place of the flame/check.

### `lib/ui/widgets/week_strip.dart`
- `_IntensityBar`: shielded incomplete days render a full-width blue bar (`col.blue`) instead of an amber progress bar. Normal days still use amber at the completion ratio. Removed `🛡` emoji overlay (user preference).
- Navigation arrows: Monday `<` jumps −1 day (to Sunday) instead of −7; Sunday `>` jumps +1 day (to Monday). All other days still jump ±7 for week-by-week navigation.

### `lib/ui/inspector/inspector_pane.dart`
- `InspectorPane` now watches `dayShieldsProvider`.
- `_HabitInspector` receives `comps` and `shieldedDays`; displays a `done (90d)` row in the streak block counting actual completions plus shielded days where the habit was due but not completed.

### `lib/ui/views/stats_view.dart`
- Overview block shows `shielded days` counter (90-day window, sourced from `dayShieldsProvider`).

---

## Design deviations from spec

| Spec item | Implemented as |
|-----------|---------------|
| `🛡` emoji overlay on week strip day cells | Full-width blue bar on the intensity bar instead — cleaner at the cell scale, no emoji stacking. User-requested change. |
| `createdAt` gate not in original spec | Added: shield spending is only allowed on days `≥ max(habit.createdAt)`. Prevents a backdated habit from triggering retroactive shield spending that the user never experienced. |

---

## Key bugs fixed during development

| Bug | Root cause | Fix |
|-----|-----------|-----|
| Shields only visible after re-login | `runLaunchScan` captured completionMap at launch; if user marked habits before scan completed, pass 2 overwrote pool with stale data | Post-scan `_recomputePool()` in `.then()` callback |
| Shield bar showing after all habits deleted | `weeklyRatios` set `shielded=true` even when `due=0`; orphaned shield rows left in DB | `due > 0` guard in provider; empty-habits cleanup in both scan functions |
| Shield spent even when overall streak broken | `spendingStreak` not tracked through walk; shield spent whenever `shields > 0` | Seed `spendingStreak` from `computeOverallStreak.pending`; gate spend on `spendingStreak > 0` |
| Timezone: Set.contains always false | Drift returns `DateTime(isUtc=false)`; `DateTime ==` checks the flag | `.toUtc()` on all DB-returned shield datetimes before Set insertion |
| `_dayFullyComplete` comparison failure | `shield.day` passed as `dUtc` was `isUtc=false`; completion `c.day.toUtc()` was `isUtc=true` | Re-derive UTC via `localMidnightUtc(d)` |
| "Allow future marking" not persistent | `allowFutureMarkingProvider` disposed after settings dialog closed; `ref.read` returned loading state | `ref.watch` in `AppScaffold.build()` keeps it alive |
| Auto-recovery not working mid-session | `recomputeShieldPool` not called on completion changes | `ref.listen(recentCompletionsProvider, ...)` triggers `_recomputePool()` on every write |
