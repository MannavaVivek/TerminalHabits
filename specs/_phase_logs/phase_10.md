# Phase 10 — Cloud sync / Supabase auth

**Completed: 2026-05-20**

## What was built

### Auth
- Supabase email/password auth via `supabase_flutter ^2.12.4` (already in pubspec).
- `LoginView`: `signInWithPassword` → `ensurePlaceholderUser` → `pullAll` → push if server empty → route based on seenOnboarding + habit count.
- `RegisterView`: `signUp` → auto `signInWithPassword` if session null (email confirm disabled) → onboarding. Falls back to LoginView redirect if confirm required.
- `ForgotPasswordView`: `resetPasswordForEmail` with confirmation state.
- `SplashView`: checks `Supabase.instance.client.auth.currentSession` to decide authenticated vs login.
- `UserWindow`: `supabase.auth.signOut()` on log out.
- `lib/config/supabase_config.dart` holds credentials (gitignored).

### Sync
- `SyncService` (`lib/data/sync_service.dart`): `pushAll()` and `pullAll()`.
- Push: delete all server rows in FK-safe order, then upsert local rows in parent-first order.
- Pull: fetch all server rows, guard on `serverHabits.isEmpty`, delete-all local, reinsert from server in Drift transaction. Returns `bool` (true = pulled, false = skipped).
- `SyncService.isPulling` static flag + 3s cooldown suppresses auto-push after a pull.

### Auto-push
- `AppScaffold` listens to `habitsProvider`, `recentCompletionsProvider`, `groupsProvider`, `vacationsProvider`. Any emission triggers a 2s debounced `pushAll()`. Covers all write sites without touching them individually.

### Manual sync (Mac)
- `Cmd+R` → `SyncIntent` → `_syncNow()` → `pullAll()`.
- `[ sync with cloud ]` entry in command palette (`Cmd+K`).

## Bug fixes during testing
- macOS sandbox missing `com.apple.security.network.client` — added to both entitlements files.
- `User` name conflict between `supabase_flutter` and Drift — `hide User` import.
- Registration redirecting to login without clearing `seenOnboarding` — fixed with auto sign-in after `signUp`.
- Login going to daily instead of onboarding on fresh device — post-pull habit count check.
- Habits not reaching Supabase after onboarding — push was only in onboarding; fixed by adding auto-push to AppScaffold.
- Android push overwriting Mac deletions on pull-to-refresh — removed `pushAll()` from daily refresh; refresh is pull-only.
- `duplicate key` error from concurrent pushes — switched back to `upsert` after delete in `_pushCompletions`.
- Deleted habits/completions/groups not propagating — pushAll was upsert-only; changed to full delete+reinsert.
- Race condition: Android pull during Mac push returns empty habits → wipes local → auto-push propagates empty state. Fixed: `serverHabits.isEmpty` guard + `isPulling` cooldown.
- macOS key-repeat Flutter assertion breaking `Cmd+R` / `Cmd+K` — intercepted via `FlutterError.onError` + `HardwareKeyboard.instance.clearState()`.
- `RefreshIndicator` not triggering on empty list — wrapped all body states on Android; added `AlwaysScrollableScrollPhysics`.
- Icon/color row overflow on Android — changed side-by-side layout to stacked rows in `EditHabitDialog`.

## Deferred to Phase 11
- Supabase Realtime (WebSocket) for push-based sync without manual pull.
- Row-level upsert merge instead of full replace-all (needed for true conflict resolution).
- Tombstone pattern for deletions (currently "delete all habits" on one device won't propagate).
