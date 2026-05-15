# Phase 7 — Smoke log

**Completed:** 2026-05-14  
**Phase:** macOS Polish — stats, vacation, tracking types, streak accuracy

---

## Quality gates

| Gate | Status |
|------|--------|
| `flutter analyze --no-fatal-infos` clean | ✓ 0 errors, 0 warnings |
| `flutter test` green | ✓ |
| Manual smoke (below) | ✓ |
| New deps with Decision Log | syncfusion_flutter_datepicker (date range picker) |
| Spec files updated | ✓ roadmap.md updated |

---

## Stats view

- Stats view renders Overview, Streaks, Rates, Contributions grid, Day-of-Week bars.
- Vacation days excluded from all stats computations (perfect days, top streak, rates, dow bars).
- Loading guard includes `vacAV.isLoading` — stats never flash stale zero-vacation state on first load.

---

## Vacation

- Multiple concurrent vacations supported (startVacation no longer deactivates others).
- Vacation days are **neutral** in both per-habit and overall streak walks — neither advance nor reset.
- `endVacationNow` only caps end to yesterday when the original end date is in the future; past-only vacation date ranges are preserved.
- Syncfusion range picker used for vacation scheduling — one popup selects start + end.
  - Single-tap = single-day vacation.
  - Dragging backwards (end-of-month → today) correctly normalized: min/max applied after selection.
  - Future vacation dates allowed (no `allowFutureMarking` restriction on vacations).
- Right pane shows empty panel when selected day falls inside an active vacation.
- User window shows all currently active vacations with individual [end now] buttons.
- Manage vacations dialog: upcoming / past categories, 90%-wide divider, [cancel]/[delete] per row.
- Week strip progress bar shows zero fill on vacation days.
- Total completions counter excludes vacation-day completions.

---

## Streak accuracy

- `StreakResult` gained `streakStartUtc` — UTC midnight of the first day in the currently displayed streak chain (null when streak = 0).
- `computeStreaks` tracks `currentStart` (resets on miss, set on first day of a new run) and `pendingStart` (snapshot after phase-1 walk through yesterday).
- `HabitRow` uses `streakStartUtc` to colour past done-days: amber only when the selected day ≥ streak start AND the habit was completed that day. Broken-streak days (e.g. Mon–Thu done, Fri–Sun missed) render gray even if today's streak is active.

---

## New habit dialog

- Section order: name → dates → schedule → tracking → color → group.
- Syncfusion range picker replaces two separate `showDatePicker` calls — start and end selected in one popup.
  - Single-tap = start date only (no end date / infinite habit).
  - Same-day range treated as infinite (end date cleared).
- Spacing between sections increased (`_SecHeader` top padding `s22`).

---

## Notes

- `buildVacationDaySet` made public (was `_buildVacationDaySet`) — consumed by stats view, providers, and week strip.
- `_TogglePill` widget removed from new_habit_dialog.dart (replaced by the range picker).
- `syncfusion_flutter_core 33.2.5` pulled in transitively by the date picker package.
