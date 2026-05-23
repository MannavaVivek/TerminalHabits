# Phase 12 — Android polish + Health Connect

**Completed: 2026-05-23**

## What was built

### App icon (Android + macOS)
- Single 1024×1024 source image at `assets/icon/terminal_habits_icon.png`.
- `flutter_launcher_icons` generates the Android mipmap set and the macOS `AppIcon.appiconset`.
- macOS `flutter clean` was required once to wipe Xcode's cached asset bundle; once flushed, the new icon appears in the dock.

### Archive snackbar position
- `BorderedToast.show` now reads `MediaQuery.padding.bottom` on Android and offsets the toast above the system nav bar + FAB (`sysInset + 52 + 20 + 12`). On Mac/Linux the toast keeps its 32 px bottom margin.
- The `_BorderedToast` widget gained a `bottom` parameter passed through from the entry builder so the offset can be platform-aware without forking the widget.

### Haptic feedback audit
- All haptic calls reduced to **archive + delete only**, per explicit user preference.
- Kept: `HapticFeedback.mediumImpact()` in `habit_menu.dart` (archive + delete confirmation, both bottom-sheet and popup menu paths) and on the left-swipe (archive) gesture in `habit_row.dart`.
- Removed: long-press menu open, checkbox tap, right-swipe (edit), and the new-habit FAB tap.

### Password recovery (deep link)
- Custom URL scheme `terminalhabits://` registered in `macos/Runner/Info.plist` (`CFBundleURLTypes`) and `android/app/src/main/AndroidManifest.xml` (intent filter for `VIEW + DEFAULT + BROWSABLE`, scheme + host `login-callback`).
- `app_links: ^6.3.4` added to receive the URI at the Flutter layer.
- `App` widget converted to `ConsumerStatefulWidget` with `_initDeepLinks` (handles both `getInitialLink` and `uriLinkStream`) + `_initAuthListener` on `supabase.auth.onAuthStateChange`.
- On receiving `terminalhabits://login-callback#…&type=recovery`, calls `supabase.auth.getSessionFromUrl(uri)` which fires the `passwordRecovery` auth event; the listener then navigates to `ResetPasswordView` via a root `_navigatorKey`.
- `ResetPasswordView` (new file) collects new password + confirm, calls `updateUser(password:)` then `signOut(scope: SignOutScope.global)` to invalidate every session. The shared `signedOut` listener routes the current device — and every other device whose session is now invalid — to `LoginView`.
- `forgot_password_view.dart` passes `redirectTo: 'terminalhabits://login-callback'` so Supabase honors the custom scheme.
- `SplashView._proceed()` calls `refreshSession()` on every cold start. If the refresh token was revoked (someone changed the password elsewhere and the global sign-out invalidated it), the call throws and we fall through to `LoginView`. Network errors proceed with the cached session (offline mode).
- App-required limitation accepted: the recovery link only works on a device that has the app installed. No web fallback page.
- `passwordRecoveryActiveProvider` (StateProvider) flags the cold-start race so `SplashView._proceed()` doesn't override the recovery navigation when the user taps the splash before the link is fully processed.

### Editable groups + LWW sync
- `Groups` table gained `updated_at` + `deleted` columns (schema v10) for LWW + tombstone sync, mirroring habits/completions from Phase 11.
- All group mutations (`createGroup`, `renameGroup`, `setGroupNote`, `setGroupCollapsed`, `patchGroup`, `deleteGroup`) stamp `updatedAt = now()`.
- `deleteGroup(id, {reassignTo})` is now soft-delete:
  - `general` is protected and cannot be deleted (no-op).
  - With `reassignTo`: habits' `groupId` moves to the target group; group row gets `deleted = true`.
  - Without `reassignTo` (cascade): habits in the group get `deleted = true, updatedAt = now()` alongside the group.
- Delete dialog restored the reassign-or-cascade radio choice (user explicit preference). Default selection is reassign to the first available group; cascade is opt-in.
- `general` group: `rename` and `delete` options hidden from the group context menu entirely.
- Empty rename input now routes to the same delete confirmation flow.
- `watchGroups` and `getGroups` filter `deleted = false`. New `getAllGroups` returns tombstones too — used by sync push so deletions propagate.
- `SyncService` push/pull/realtime use LWW for groups (compare `updatedAt`, only newer wins). No more hard-delete diff for groups.
- Menu position bug: `onLongPress` doesn't give us press coords, so the popup landed at `(0, 0)`. Switched both `habit_group.dart` and `habit_row.dart` to `onLongPressStart` which provides `details.globalPosition`.

### Display name change (via settings popup)
- Removed inline tap-to-edit on the user-window name row (was undiscoverable on Mac, broken on Android).
- New `change_name_dialog.dart` — a popup with text field + save/cancel that writes to both the local `users` table and Supabase user metadata (`data['display_name']`).
- New `[ change name ]` button in both Settings (Mac) and Mobile Settings (Android), under a new `account` section.
- `currentUserProvider` is invalidated after save so the user window header refreshes immediately.
- Cross-device propagation: `SplashView._proceed()` reads `currentUser.userMetadata['display_name']` after `refreshSession()` and applies it to the local `users` table. Every cold launch picks up the latest name set on any other device.

### Centralized version and storage label
- New `lib/app_info.dart` with `kAppVersion = '0.4.0'` and `kAppStorage = 'supabase + local sqlite'`.
- Splash, window chrome, Mac settings, and mobile settings now all read these constants.
- `pubspec.yaml` bumped to `0.4.0+6`.
- Removed the stale "passwords are stored in plaintext — Phase 11" footnote from settings.

### Health Connect — Android auto-tracking
Vertical slice for **steps**, then extended to **sleep** and **exercise**.

- `health: ^13.1.1` + `permission_handler: ^11.3.1` added to pubspec.
- `minSdk` bumped to 26 (Health Connect requirement).
- Manifest: `READ_STEPS` / `READ_SLEEP` / `READ_EXERCISE` permissions, `com.google.android.apps.healthdata` package query, `PERMISSIONS_RATIONALE` intent filter, and `ViewPermissionUsageActivity` alias for Android 14+'s permission-usage screen.
- `HealthService` (new): `hasPermissions(sources)`, `requestPermissions(sources)` (with hasPermissions re-check workaround for the plugin returning `false` when no system UI was shown), `readTodayValue(source)`, and `diagnose(source)` for in-app debugging.
- `kHealthSources` config map drives the UI: each source has `goalUnitLabel` (`steps`/`hours`/`minutes`), a hint string, `goalToInternal` + `internalToGoal` converters (sleep stores minutes internally but accepts hours), and a `storedUnit` written to `habits.unit`.
- `HealthDataType` mapping: `steps → STEPS`, `sleep → SLEEP_SESSION`, `exercise → WORKOUT`.
- `readTodayValue` uses `getHealthDataFromTypes` (canonical Health Connect path; aggregates across all data sources). For steps it sums numeric points; for sleep/exercise it sums session **durations in minutes** and filters by `dateTo` falling in today's local-day window. Sleep extends the query window 24h back so overnight sessions get attributed to the wake-up day.
- New + edit habit dialogs: `health` pill (Android only); source picker; goal field with per-source label/hint; `[ test health connect ]` button shows permission state + today's read count.
- `habit_row._progressLabel` formats per-source: steps as `K`-format (`7.2k/8k`), sleep as decimal hours (`7.0h/8h`), exercise as raw minutes (`25m/30m`).
- `ValueInputDialog` scales for health: max value 999,999, max digits 6, step size scales with the target (~target/20, clamped to 50–1000).
- `runHealthSync(db, habits)` runs on every cold start (after the initial pull) and on every pull-to-refresh.
- `runHealthSync` write rules:
  - No row, or row with `deleted = true` (user cleared) → write the HC value fresh. Treating a cleared row as "resume auto-tracking" lets the user undo a manual override.
  - Row with `value > 0` and `deleted = false` → only update if `HC > existing.value`. Never downgrade a manual override.
  - HC value of 0 or read failure → leave the row alone.
- Tap-to-clear on a health habit immediately fires `runHealthSync` for that habit so the row picks up Health Connect's value without waiting for the next pull.
- `isDoneToday` and `_buildCompletedDaySet` (streaks) now gate health habits on `value >= target` (same as counter/duration).

### Launch shield scan timing
- `SyncService.initialPullCompleted` (Completer): completed when the catch-up `pullAll` triggered by Realtime subscribe finishes.
- `AppScaffold._runScanAsync` awaits this completer (with a 5 s offline-mode timeout) before running the launch shield scan **and** before running `runHealthSync`. Previously the scan could run on stale local data, advance `last_seen_date` past missed days, and lock in missed-shield outcomes that should have been recoverable. Health sync had a related race where Mac would write completions before pull and then push out-of-date diffs that erased Android's correctly-applied shields.

## Bugs fixed during testing

- Menu position bug on long-press: `onLongPress` doesn't give coords → switched to `onLongPressStart`.
- Group LWW year-58000: v10 migration backfilled `updated_at` in milliseconds, which Drift (storing `DateTime` as Unix seconds) read as year-58000 timestamps. Local always "won" LWW, blocking sync. Fixed: v10 now writes seconds; v11 recovery migration resets bogus values to 0. Added `_safeUpdatedAt` helper that clamps any read past year-3000 to epoch so server-side bogus values don't reinfect local on pull.
- Realtime callback returning `false`-ish on permission grant: `requestAuthorization` returns false when no system UI is shown (which happens after a prior interaction). Fixed: `HealthService.requestPermissions` re-checks `hasPermissions` and trusts the more-recent answer.
- Health habit blocked save when permission was missing: removed the block; habit is saved regardless and a help dialog explains how to grant via Health Connect → App permissions. Auto-sync silently skips habits without permission.
- `getTotalStepsInInterval` not aggregating across data sources reliably: switched to `getHealthDataFromTypes` which Health Connect uses internally; sums every data point in the window.
- Day-key mismatch: `runHealthSync` was writing `DateTime.utc(y,m,d)` but the rest of the app stores `day` as local-midnight-UTC. For any user not in UTC+0 these are different timestamps, so the UI looked up "today's completion" with a key that the sync never wrote. Fixed via `localMidnightUtc(DateTime.now())`.
- `(habit_id, day)` UNIQUE conflict in Realtime apply: server's autoincrement id ≠ local's autoincrement id for the same logical row, so applying by-id failed when local already had a row for that `(habit, day)`. Fixed: both `pullAll` and the Realtime handler now look up by `(habit_id, day)` when no by-id match exists; LWW chooses which row wins, and the loser is hard-deleted so the upsert can proceed.
- Pull-to-refresh wiping a freshly-created habit: pull's diff-delete pass treated "row on local but not on server" as a remote deletion. With soft-delete (Phase 11) this is wrong — local rows missing from server may just be local creations awaiting their debounced auto-push. Fixed: `pullAll` no longer hard-deletes habits or completions (tombstones handle deletions). Pull-to-refresh now pushes first, then pulls, closing the race for tables that don't have soft-delete (shields, history, vacations).
- `setCompletionValue` colliding with a soft-deleted row on the same `(habit, day)`: the lookup filtered `deleted = false` so a soft-deleted row wasn't found, then the insert hit the UNIQUE constraint. Fixed: lookup now ignores `deleted`; reactivates the soft-deleted row instead of inserting.
- "Walking 1 step shows 1/100" / "can't increase value": tap on health habit was routing to the default branch (`toggleCompletion`, treats value as bool). Routed health to the same `ValueInputDialog` path that counter/duration use.
- Health habit value progress not visible below the goal: `runHealthSync` was only writing when `value >= target`. Now writes every sync; `isDoneToday` decides the green/done state.
- Manual override getting downgraded: added the "only advance, never lower" rule in `runHealthSync`.
- Manual clear not resuming auto-tracking: soft-deleted row was being skipped forever. Reinterpreted soft-delete on a health row as "resume auto mode"; the next sync writes the HC value fresh. Tap-to-clear fires sync immediately.

## Schema migrations

- v10: `groups.updated_at INTEGER NOT NULL DEFAULT 0`, `groups.deleted INTEGER NOT NULL DEFAULT 0`. Backfill `updated_at = now()` in **seconds** (Drift's `DateTime` storage convention).
- v11: recovery migration — resets `groups.updated_at` to 0 for any row past the year-3000 threshold (32503680000000 ms), to fix databases that ran the buggy initial v10 (which backfilled in ms instead of seconds).

## Supabase SQL required

```sql
-- Run once in Supabase SQL editor (Phase 12 add-on to Phase 11's setup)
ALTER TABLE groups ADD COLUMN IF NOT EXISTS updated_at BIGINT;
ALTER TABLE groups ADD COLUMN IF NOT EXISTS deleted    BOOLEAN NOT NULL DEFAULT FALSE;
UPDATE groups SET updated_at = EXTRACT(EPOCH FROM now()) * 1000 WHERE updated_at IS NULL;

-- Allowed redirect URL for password recovery deep link:
-- Dashboard → Authentication → URL Configuration → Redirect URLs
-- Add: terminalhabits://login-callback
```

## Deferred / not done in this phase

- Exercise auto-tracking validated only via the diagnostic; live end-to-end test pending a real workout session being recorded.
- Additional Health Connect sources (water, active calories) explicitly declined by user.
- `ValueInputDialog` doesn't convert sleep's internal minutes to hours for manual override entry — user enters minutes (e.g. 420 for 7 h). Goal entry in the new/edit dialog already converts; only the manual-override path is in internal units. Acceptable since manual override of sleep is rare.
