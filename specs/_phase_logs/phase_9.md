# Phase 9 — Smoke log

**Completed:** 2026-05-19  
**Phase:** Android adaptation

---

## Quality gates

| Gate | Status |
|------|--------|
| `flutter analyze --no-fatal-infos` clean | ✓ 0 errors, 0 warnings |
| Manual smoke on Android device | ✓ |
| No Mac regressions | ✓ user-verified |
| New deps with Decision Log | none |
| Spec files updated | ✓ roadmap.md updated |

---

## New files

- `lib/ui/mobile/mobile_sub_page.dart` — thin `Scaffold` wrapper for pushable Android full-screen pages (back button + title bar).
- `lib/ui/mobile/mobile_settings_page.dart` — Android-only full settings page; theme picker with live preview, font size section omitted (textScaler disabled on Android).

---

## Modified files

### `lib/app.dart`
- `textScaler`: `Platform.isAndroid ? TextScaler.noScaling : TextScaler.linear(scale)`. Disabling system font-scale on Android prevents fixed-layout overflow; Mac keeps the scale preference.

### `lib/ui/views/app_scaffold.dart`
- Removed `LayoutBuilder`; `isMobile = Platform.isAndroid` directly in `build`. Fixes landscape-Android being misdetected as desktop (old `< 720px` breakpoint fired in landscape).
- `PopScope(canPop: view == 'daily')` wraps `_MobileBody` so Android back button navigates to daily view rather than closing the app from non-daily screens.
- Removed swipe-up inspector chip and `_InspectorChip` / `mobile_inspector_sheet` import — removed entirely on mobile.
- `resizeToAvoidBottomInset: false` on the main `Scaffold` — prevents keyboard from squishing the background layout when a dialog is open.

### `lib/ui/mobile/mobile_top_bar.dart`
- Tabs centered with `Row(mainAxisAlignment: center)` instead of start-aligned.

### `lib/ui/views/profile_view.dart`
- Vacation, archive, and settings links use `Navigator.push(MaterialPageRoute)` on Android and `currentViewProvider` state swap on desktop — proper back-stack on mobile.

### `lib/ui/nav/sidebar.dart`
- `archive` nav item added after `stats`. Was accidentally removed from desktop access when the archive section was stripped from the settings dialog.

### `lib/ui/views/daily_view.dart`
- Removed outer `Padding(horizontal: TH.s14)` around `WeekStrip` so it uses full available width on mobile.

### `lib/ui/widgets/week_strip.dart`
- Arrow tap target width 20 → 14; inter-cell gap 4 → 2. Gives day cells more room on narrow screens.

### `lib/ui/widgets/contribution_grid.dart`
- Added `ScrollController`; `initState` postFrameCallback `jumpTo(maxScrollExtent)` so grid starts scrolled to the most recent week.
- DOW label column extracted outside `SingleChildScrollView` so labels stay fixed while week columns scroll horizontally.

### `lib/ui/views/vacation_view.dart`
- `_promptDays` replaced by `showDateRangePicker` for both creating and editing vacations — user picks start+end dates instead of entering a day count.
- "extend" button renamed "edit"; edit now allows changing start and end (full range).
- Active vacation block split to two lines (start and end on separate rows).
- `_formatPast`: if `end < start` (cancelled same-day), shows `(cancelled)` instead of a reversed range.
- `_PalmTree` widget removed.

### `lib/data/database.dart`
- `editVacation(int id, DateTime newStart, DateTime newEnd)` added to support full-range vacation editing.

### `lib/ui/modals/settings_dialog.dart`
- Removed `_ArchiveList` / `_ArchivedItem` and the "data" section. Archived habit management moved to the dedicated Archive view.

### `lib/ui/modals/new_habit_dialog.dart`
- `insetPadding` fixed to `const EdgeInsets.all(12)` — removes double keyboard-height shift (old code added `keyboardH` on top of Flutter's own viewInsets addition).
- Restructured to `ConstrainedBox(maxWidth) → SingleChildScrollView → Column(min)` — eliminates landscape overflow that occurred with `Column(mainAxisSize:min) + Flexible(ScrollView)` structure.

### `lib/ui/modals/new_group_dialog.dart`
- Same `insetPadding` and scroll structure fix as `new_habit_dialog`.

### `lib/ui/modals/edit_habit_dialog.dart`
- Same `insetPadding` fix; `maxHeight` constraint removed (Dialog's `AnimatedPadding + viewInsets` handles height natively).

### `lib/ui/views/splash_view.dart`
- `SafeArea(minimum: EdgeInsets.all(TH.s14))` wraps body so system bars don't cut into content on phone.

### `lib/ui/views/login_view.dart`
- `LayoutBuilder + SingleChildScrollView + ConstrainedBox(minHeight)` pattern makes the form keyboard-safe and vertically centered.

### `lib/ui/views/onboarding_view.dart`
- Starter habit definitions: emoji strings (`🧘`, `📓`, `💪`, `📚`, `💧`, `🌙`) replaced with Lucide icon keys (`brain`, `pencil`, `dumbbell`, `book`, `droplets`, `moon`).
- `_StarterHabitsStep` renders icons via `lucideIconData()` instead of `Text(emoji)`.

---

## Design deviations from spec

| Spec item | Implemented as |
|-----------|---------------|
| `LayoutBuilder < 720px` breakpoint | `Platform.isAndroid` — breakpoint approach misdetects landscape Android as desktop |
| Inspector collapses to bottom-sheet drawer | Removed on mobile entirely — the inspector pane is desktop-only; mobile sees only the daily list |
| `MobileCommandBridge` GridView palette | Not implemented — profile page navigation and FAB cover primary actions; palette not needed on touch |
| `health_connect` integration | Deferred post-1.0 |
| Android app icon | Deferred |
| Long-press context menu, swipe-right quick edit | Deferred |

---

## Key bugs fixed during development

| Bug | Root cause | Fix |
|-----|-----------|-----|
| Landscape Android showed desktop sidebar | `constraints.maxWidth < 720` fired in landscape (wide) | `Platform.isAndroid` unconditionally |
| Dialog "fly away" on keyboard up | `insetPadding.bottom = keyboardH + 12` added on top of Flutter's own `viewInsets.bottom` → double shift | Fixed `insetPadding: const EdgeInsets.all(12)` |
| Landscape overflow in `new_habit_dialog` | `Column(mainAxisSize:min) + Flexible(ScrollView)` — Flutter uses intrinsic (full content) height for Flexible in min-size column | Restructured to `SingleChildScrollView + Column(min)` |
| Background layout crushed by keyboard | `Scaffold.resizeToAvoidBottomInset` defaulted true; dialog keyboard shrank the entire scaffold to ~57px | `resizeToAvoidBottomInset: false` on main scaffold |
| Contribution grid DOW labels scrolled away | Entire Row (labels + cells) was inside `SingleChildScrollView` | Labels column extracted outside scroll; only week columns scroll |
| Back button closed app from vacation/stats | No `PopScope` on mobile body | `PopScope(canPop: view == 'daily')` in `_AppScaffoldState` |
| Vacation "18 to 17" display | `endVacationNow` sets end = yesterday; formatting showed reversed range | `_formatPast` shows `(cancelled)` when `end < start` |
| Onboarding habits stored emoji strings as icon key | `_starterDefs` tuples used literal emoji as the icon field | Replaced with Lucide key strings |
