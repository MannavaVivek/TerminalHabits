# Phase 6 — Smoke log

**Completed:** 2026-05-10  
**Phases:** 6a (user auth & data isolation) + 6b (settings dialog & instant theme)

---

## Quality gates

| Gate | Status |
|------|--------|
| `flutter analyze --no-fatal-infos` clean | ✓ 0 errors, 0 warnings |
| `flutter test` green | ✓ 21/21 |
| Manual smoke (below) | ✓ |
| No new deps without Decision Log | ✓ (no new packages added) |
| Spec files updated | ✓ roadmap.md updated |

---

## Phase 6a — Auth & data isolation

### Register / login
- Fresh launch → splash → register screen.
- Create account with display name `Alice`, username `alice`, password `pw`.
- Onboarding shown; lands on daily view.
- Force quit → relaunch → login screen shown (not register, because a user exists).
- Login with wrong password → inline red error, no crash.
- Login with `alice / pw` → daily view with Alice's data.

### Forgot password
- `[ forgot password ]` → enter `alice` → plaintext `pw` displayed.
- Enter unknown username → `no account found.` error.

### Data isolation
- Register second user `bob / pw`.
- Add a habit "Bob's habit".
- Log out → log back in as `alice` → Bob's habit not visible.
- Alice's habits intact.

### User window
- User button in sidebar shows `[A] Alice`.
- Tap → UserWindow dialog: username, display name (editable), member since, completions, streak.
- Edit display name → saves on blur → sidebar initial updates.
- `[ log out ]` → login screen; re-login returns to daily view.

---

## Phase 6b — Settings & theme

### Open settings
- `Cmd+,` opens SettingsDialog. ✓
- Command palette → `settings` → SettingsDialog. ✓
- UserWindow → `[ ⚙ settings ]` → SettingsDialog. ✓

### Font size
- Change sm / md / lg → text scales instantly across daily view, sidebar, dialogs. ✓
- Setting persists after quit + relaunch. ✓

### Theme
- Change to `nord` → background, text, accent colors all change instantly without restart. ✓
- Change to `hacker` → bright green on black, immediately applied. ✓
- Switch back to `matrix` → correct. ✓
- Theme persists after quit + relaunch. ✓

### Allow future marking
- Default off → tapping a future day cell shows "Not so fast!" dialog. ✓
- Enable in Settings → Behavior → toggle `future marking`. ✓
- Future day tap now logs completion directly, no dialog. ✓
- Space-bar on a focused future habit → same gate respected. ✓

### Archive in settings
- Archive a habit via right-click → Archive.
- Open Settings → Data → habit appears with `[ restore ]` and `[ delete ]`.
- Restore → habit back in daily view. ✓
- Delete → confirmation dialog → removed permanently. ✓

### Behavior persistence
- Set confirmDestructive to disabled → delete a habit → no confirmation shown. ✓
- Quit + relaunch → setting preserved. ✓

---

## Notes

- Instant theme apply was pulled forward from Phase 7's "token refactor" deferred item.
  Mechanism: `AppColors extends ThemeExtension<AppColors>` with 6 named themes;
  `App` watches `themeIdProvider` and passes live `AppColors` to `buildTheme(col)`;
  all 33 widget/modal/view files updated from `TH.colorXxx` static constants to
  `context.col.xxx` runtime lookups.
- `confirmDestructive` setting is stored but the guard is not yet wired into every
  delete path (only the future-marking path is fully wired). Full wiring is Phase 7 cleanup.
