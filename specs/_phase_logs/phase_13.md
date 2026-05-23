# Phase 13 — Backup, polish, and Phase 12 follow-ups

**Completed: 2026-05-23**

## What was built

### Sleep value dialog — hours mode
`ValueInputDialog` now works in display units (hours for sleep, minutes for
duration, raw count for steps/exercise). A new `_displayFactor` converts at
the boundaries: incoming `currentValue` (always in internal units) is divided
on init, and the returned value is multiplied on confirm.
- For sleep: max = 24, step = 1, unit suffix = `h`, max-digits = 2.
- Quick-value chips also display in hours.
- Subtitle (`tracking · target …`) shows hours, not minutes.
- Steps and exercise paths unchanged (factor = 1).

### macOS can configure health habits
- Removed the `Platform.isAndroid` guard on the `health` pill in both
  `new_habit_dialog.dart` and `edit_habit_dialog.dart`.
- On macOS the permission request and the denied-help dialog are skipped
  (there's no Health Connect on macOS). The habit is just saved and synced
  to Android via the existing pipeline; Android picks it up and does the
  actual auto-tracking.

### Launch-scan summary toast
- `runLaunchScan` returns `LaunchScanResult { daysScanned, daysShielded,
  daysMissed }` (previously void). Early returns return `LaunchScanResult.empty`.
- `AppScaffold._runScanAsync` captures the result and shows a
  `BorderedToast` if `hasNotableActivity` (any day shielded or missed).
  Message format: `while you were away: 2 days shielded, 1 day missed`.
  Suppressed when the user opened the app yesterday (scan range empty).
- Toast lasts 4.5 s.

### JSON import / export
- New `file_picker: ^8.1.4` dependency.
- New `lib/domain/data_export.dart`:
  - `exportAllToJson(db)` — dumps every Drift row from groups, habits,
    history, completions, vacations, day_shields, app_settings via the
    generated `toJson()` per data class, wrapped in a versioned envelope
    (`schema`, `exportedAt`, `appVersion`).
  - `peekImportConflicts(db, jsonStr)` — returns the list of habit names
    in the JSON that match an existing (non-deleted) local habit. Caller
    uses this to prompt before the destructive step.
  - `importFromJson(db, jsonStr, conflictResolution: …)` — **merge** import:
    - Groups match by name. Local id reused when a name matches. New groups
      get a fresh UUID if the JSON's id collides with an unrelated local id.
    - Habits match by name. With `replace`, the conflicting local habit and
      all its completions are soft-deleted (tombstones propagate via sync)
      and the JSON's version is inserted with a fresh auto-increment local
      id. With `keepLocal`, the JSON's habit + its completions are skipped
      entirely.
    - Completions and history reference `habit_id`, which is autoincrement
      and per-device — they're remapped through the habit-id mapping built
      during habit import. Anything tied to a kept-local habit is skipped.
    - Vacations and shields are appended as-is with fresh ids.
    - `app_settings` are intentionally not imported (device-local).
    - Imported rows that carry `updatedAt` are stamped to `now()` so a
      subsequent push wins LWW against existing server rows.
- New `lib/ui/modals/data_backup_actions.dart` — `handleExportBackup` /
  `handleImportBackup` flows.
  - Export: prompts for save location via `file_picker.saveFile`; passes
    bytes only on Android (macOS rejects the `bytes` arg). On Mac/Linux we
    write the file ourselves after `saveFile` returns the path.
  - Import: picks file, peeks conflicts, prompts for resolution if any,
    runs the merge, then pushes to Supabase if signed in. Surfaces partial
    failure (e.g. "cloud push failed: …") without losing the local merge.
- UI: new `data` section in both Mac (`settings_dialog.dart`) and Android
  (`mobile_settings_page.dart`) settings, with `[ export ]` / `[ import ]`
  buttons under a `backup` row.

### Sync push resilience
- `pushAll` now skips the seeded `general` group entirely. Its id is the
  literal string `general` (a deterministic seed shared across every
  device and every account) and the `groups` table's primary key is
  global, not per-user. If a stale row with that id exists on the server
  owned by another account, the upsert resolves to UPDATE → Postgres RLS
  rejects the OLD row under the `USING` clause. Skipping it is safe
  because `_seedDefaults` re-creates it on every device.
- Every per-table upsert in `pushAll` is now wrapped in `try/catch`. One
  failing table no longer blocks the rest of the push.

### macOS file-picker entitlement
- Added `com.apple.security.files.user-selected.read-write` to both
  `DebugProfile.entitlements` and `Release.entitlements`. Without it,
  `file_picker`'s save/open dialogs failed silently inside the macOS
  sandbox.

## Bugs fixed during testing
- `TableInfo` and `Table` were not in scope: the narrow `show Value`
  import in `data_export.dart` blocked the macOS build. Expanded to
  `show Value, Insertable, TableInfo, Table`.
- `newUuid()` is defined in `lib/data/tables.dart` but not re-exported
  through `database.dart`; switched to `Uuid().v4()` from the `uuid`
  package directly.
- `file_picker.saveFile(bytes: …)` is unsupported on macOS — pass bytes
  only on Android; write the file ourselves on Mac/Linux after the path
  is returned.
- `general`-group RLS rejection (described above).

## Supabase SQL — one-off

Documented in `specs/supabase_phase_13_dedupe.md`. The DELETE statement
keeps the most-recently-updated row per `(user_id, habit_id, day)` and
purges duplicates accumulated from the Phase 12 per-device autoincrement
collisions. Verified zero duplicate rows after running.

## Deferred / not validated end-to-end

- Launch-scan summary toast is implemented but not yet validated against a
  real multi-day gap; the user is intentionally waiting to test it
  naturally during a future absence.
