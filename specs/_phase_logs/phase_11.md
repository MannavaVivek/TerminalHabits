# Phase 11 — Sync v2: Realtime + row-level merge

**Completed: 2026-05-21**

## What was built

### Supabase Realtime
- `SyncService.startRealtime(db)` subscribes to `INSERT`/`UPDATE`/`DELETE` Postgres changes on all six tables (`habits`, `completions`, `groups`, `vacations`, `habit_schedule_history`, `day_shields`) filtered by `user_id = auth.uid()`.
- On subscribe, fires a catch-up `pullAll()` to close any gap that opened while the channel was down.
- `stopRealtime()` called on logout and `AppScaffold.dispose()`.
- Wired into `AppScaffold.initState` (start) and `dispose` (stop), and `UserWindow._logOut` (stop before sign-out).
- Channel name scoped to UID (`habit-sync-$uid`) so multi-user devices don't cross-subscribe.
- Requires `REPLICA IDENTITY FULL` on all tables (so DELETE events carry full row data for `user_id` filter matching).

### Diff-based push (no more bulk delete)
- `pushAll()` fetches server ID/timestamp sets, diffs against local, and only deletes rows absent locally + upserts rows newer than server. Eliminates the delete-all→reinsert window that caused data loss on concurrent pushes.
- `_serverHabitTimestamps()` and `_serverCompletionTimestamps()` return `{id → updatedAt}` maps for LWW comparison.

### Last-write-wins (LWW) conflict resolution
- `updatedAt` column added to `Habits` and `Completions` tables (schema v8 → v9). Stamped on every create/modify/archive/soft-delete.
- Push: skips rows where server `updatedAt` ≥ local.
- Pull: skips rows where local `updatedAt` > server.
- Realtime handler: checks local `updatedAt` before applying incoming event.

### Soft-delete tombstone pattern
- `deleted BOOLEAN DEFAULT FALSE` added to `Habits` and `Completions`.
- `deleteHabit()` sets `deleted = true, updatedAt = now()` instead of hard-deleting.
- `toggleCompletion()` rewritten as explicit 3-branch logic (soft-delete / reactivate / insert) to avoid UNIQUE constraint on `(habit_id, day)`.
- All display queries filter `deleted = false`; sync queries (`getAllHabits`, `getAllCompletions`) include deleted rows so tombstones propagate.

### Multi-user local isolation
- `clearAllUserData()` wipes all user-specific tables then calls `_seedDefaults()` to restore the `general` group and default settings.
- Called on logout, on registration (before onboarding), and on login when `last_auth_uid` in SharedPreferences differs from the incoming Supabase UID.
- Prevents stale data from one account bleeding into another on the same device.
- `_seedDefaults()` group insert changed to `insertOnConflictUpdate` (idempotent).

### Login / registration flow hardening
- `LoginView` no longer shows onboarding — login always goes to `AppScaffold`. Onboarding is exclusively a registration flow. Prevents accidental re-onboarding when the server is briefly empty on a second device.
- `last_auth_uid` stored in SharedPreferences; login clears local DB only when UID changes (same user logging back in keeps offline data).
- Display name saved to Supabase user metadata (`data['display_name']`) in onboarding and profile edit; restored from metadata on every login so it survives multi-device sessions.

### Profile / UX fixes
- Username display changed from `@${local.username}` (which rendered as `@email@domain`) to Supabase `currentUser?.email` without `@` prefix. Row label changed from "username" to "email".
- "display name" label renamed to "name".
- Email removed from header (already shown in profile section).
- "Member since" year-58356 bug fixed: `customInsert` was storing `millisecondsSinceEpoch` but Drift 2.x reads `DateTimeColumn` as seconds; fixed with `~/ 1000`.
- `currentViewProvider` reset to `'daily'` on logout and in `SplashView._proceed()`, so login and app-restart always land on the daily page.
- `new_habit_dialog.dart` date-picker column wrapped in `SingleChildScrollView` to suppress overflow error when keyboard is visible during date selection.

## Bugs fixed during testing
- `in_()` → `inFilter()` (postgrest v2.7.0 API rename).
- Unchecks reverting to checked: `REPLICA IDENTITY DEFAULT` dropped DELETE `oldRecord` user_id → events silently filtered. Fix: `ALTER TABLE … REPLICA IDENTITY FULL`.
- Changes in non-general groups not syncing: `isPulling = true` in `_applyChangeAsync` suppressed auto-push after Mac's own Realtime echo. Fix: removed flag from Realtime handler (diff-based push makes echo a no-op).
- SQLite `ALTER TABLE ADD COLUMN` rejecting non-constant default: used `DEFAULT 0` + backfill `UPDATE … SET updated_at = created_at`.
- UNIQUE constraint on `(habit_id, day)` when reactivating soft-deleted completions: `insertOnConflictUpdate` targets `ON CONFLICT(id)` but the real unique key is `(habit_id, day)`. Fix: explicit 3-branch upsert logic.
- Onboarding habits not reaching Supabase: `clearAllUserData()` deleted the `general` group, so habits were created with a dangling FK; Supabase FK constraint rejected the push. Fix: `clearAllUserData()` calls `_seedDefaults()` after wiping.
- "General group missing" on second device: same root cause as above.
- Multi-user data bleed: habits from Account A visible in Account B session. Fix: `clearAllUserData()` on logout/register/user-switch.

## Schema migrations
- v8: `completions.updated_at INTEGER DEFAULT 0`, `completions.deleted INTEGER DEFAULT 0`, backfill `updated_at = created_at`.
- v9: `habits.updated_at INTEGER DEFAULT 0`, `habits.deleted INTEGER DEFAULT 0`, backfill `updated_at = created_at`.

## Supabase SQL required
```sql
-- Run once in Supabase SQL editor
ALTER TABLE habits     ADD COLUMN IF NOT EXISTS updated_at BIGINT;
ALTER TABLE habits     ADD COLUMN IF NOT EXISTS deleted     BOOLEAN NOT NULL DEFAULT FALSE;
UPDATE habits SET updated_at = created_at WHERE updated_at IS NULL;

ALTER TABLE completions ADD COLUMN IF NOT EXISTS updated_at BIGINT;
ALTER TABLE completions ADD COLUMN IF NOT EXISTS deleted     BOOLEAN NOT NULL DEFAULT FALSE;
UPDATE completions SET updated_at = created_at WHERE updated_at IS NULL;

ALTER TABLE habits       REPLICA IDENTITY FULL;
ALTER TABLE completions  REPLICA IDENTITY FULL;
ALTER TABLE groups       REPLICA IDENTITY FULL;
ALTER TABLE vacations    REPLICA IDENTITY FULL;
ALTER TABLE habit_schedule_history REPLICA IDENTITY FULL;
ALTER TABLE day_shields  REPLICA IDENTITY FULL;
```

## Deferred to Phase 12
- Swipe gestures, long-press context menu, haptic feedback matrix (Android polish).
- Health Connect integration.
- macOS code signing + notarization; Android release APK.
