# Constitution — TerminalHabits (Flutter Edition)

> The non-negotiables. Every other spec defers to this one. If a downstream spec contradicts this document, this document wins and the other spec must be amended.

---

## 1. Vision: "The Quiet Terminal"

A habit tracker that looks and feels like a terminal you actually want to live in. Calm, monospace, keyboard-first on desktop, touch-first on mobile, and identical-looking everywhere it runs.

**Product voice:** terse, lowercase, no exclamation points. Sample copy from the design reference: `// no nudges. no streak panic.` Keep that voice verbatim where it appears.

---

## 2. Non-negotiables

These are constraints. Implementations that violate them are wrong, not different.

1. **One codebase.** Single Flutter project, single `pubspec.yaml`. No platform-forks, no separate Android Studio project, no Compose, no SwiftUI.
2. **One aesthetic.** macOS, Linux, and Android share the same color tokens, type scale, border treatment, and copy. Layout adapts; visual language does not.
3. **Local-first.** SQLite (via drift) is the source of truth on every device. The app must be 100% functional offline. Cloud sync is a deferred, opt-in layer (see [roadmap.md](roadmap.md) Phase 5).
4. **Quiet UI.** No Material ripples, no bouncy curves, no shadow elevation, no spinner-style loading states. Use `NoSplash.splashFactory` globally and `kNoTransitionsBuilder` for route transitions.
5. **Monospace everywhere.** JetBrains Mono is the only UI font. Other fonts appear only as user-selectable theme options inside Settings, never as default chrome.
6. **Bordered boxes, not cards.** Containers use `DecoratedBox` with `Border.all(width: 1)`. No `Card` widget, no shadow elevation.
7. **Hybrid input, single intent layer.** Desktop dispatches to `Intent`s via `Shortcuts`/`Actions`. Mobile dispatches to the *same* `Intent`s via touch widgets. See [input_spec.md](input_spec.md).
8. **No telemetry, no analytics, no crash reporters in v1.** Add only with explicit user opt-in, post-1.0.

---

## 3. Platform divergence policy

Divergence is allowed *only* where the platform forces it. Use this checklist before adding a platform-conditional branch:

- Is this a hardware/OS difference (no keyboard on phones, no system tray on Android)? → divergence allowed.
- Is this a screen-size difference that breaks the three-pane layout? → divergence allowed (collapses to single-pane on mobile).
- Is this a stylistic preference ("Material looks better on Android")? → **rejected**. Aesthetic is uniform.

When divergence is allowed, isolate it behind one of:
- `Platform.isAndroid` / `Platform.isMacOS` / `Platform.isLinux` checks at the *layout* layer, not the data or state layer.
- A `LayoutBuilder` breakpoint (`maxWidth < 720` → mobile layout) so desktop windows resized small still degrade gracefully.

The data, repository, and state layers are platform-agnostic. They never import `dart:io` for branching.

---

## 4. Authoritative documents

This constitution governs the following specs. Read them in order on first contact:

| # | Doc | Concern |
|---|---|---|
| 1 | [constitution.md](constitution.md) | This file. Principles. |
| 2 | [tech_stack.md](tech_stack.md) | Framework, packages, layer architecture. |
| 3 | [data_model.md](data_model.md) | Drift schema, migrations, streak algorithm. |
| 4 | [feature_spec.md](feature_spec.md) | What features exist and how they behave. |
| 5 | [design_spec.md](design_spec.md) | Tokens, layouts, themes, animation policy. |
| 6 | [input_spec.md](input_spec.md) | Desktop keyboard + mobile touch unified through Intents. |
| 7 | [build_spec.md](build_spec.md) | Per-platform build, packaging, signing. |
| 8 | [roadmap.md](roadmap.md) | Phases, milestones, exit criteria. |

The UI design reference is [`../FLUTTER_NOTES.md`](../FLUTTER_NOTES.md). Treat it as a *visual* source of truth, not as a behavior spec — behavior is governed by `feature_spec.md` and `input_spec.md`.

---

## 5. Decision log

Decisions made up-front to prevent rework. Each entry: what was decided, why, and what would force us to revisit.

### D-001: Local-first, sync deferred
- **Decided:** SQLite (drift) is the source of truth. Supabase is removed from Phase 1–4 and reintroduced as opt-in cloud sync in Phase 5.
- **Why:** Original `tech_stack.md` specified Supabase but `FLUTTER_NOTES.md` specified drift; reconciling toward local-first keeps the Mac MVP unblocked by backend setup and matches the Quiet Terminal ethos.
- **Revisit if:** users explicitly request multi-device sync before Phase 5 ships.

### D-002: macOS first, then Linux, then Android
- **Decided:** Phase order is Mac → Linux → Android. Each phase ships a runnable, dogfoodable build before the next begins.
- **Why:** primary developer (you) runs macOS; fastest feedback loop. Linux is mostly a packaging exercise once Mac works. Android is the largest UX shift and benefits from a stable desktop baseline.
- **Revisit if:** Linux or Android testing demand outpaces Mac.

### D-003: drift over raw sqlite3 / hive / isar
- **Decided:** `drift` (with `sqlite3` backend) for all local persistence.
- **Why:** type-safe queries via codegen, schema migrations, well-supported on macOS/Linux/Android, pure-Dart fallback exists.
- **Revisit if:** drift codegen friction outweighs benefits in practice.

### D-004: Riverpod over Provider/Bloc
- **Decided:** `flutter_riverpod` for state.
- **Why:** compile-safe, no `BuildContext` dependency for reads, plays well with `freezed` immutables, codegen-optional.
- **Revisit if:** team grows and consensus shifts.

### D-005: Frameless window with custom chrome on desktop
- **Decided:** `windowManager.setAsFrameless()` on macOS and Linux. We render our own titlebar with traffic lights and version meta.
- **Why:** uniform visual chrome across desktop OSes; matches the design reference.
- **Revisit if:** Linux Wayland integration breaks frameless mode.

### D-006: No notifications in v1
- **Decided:** No `flutter_local_notifications`, no scheduled reminders.
- **Why:** matches the "no nudges" product voice. Would also force notification-permission UX on Android, expanding scope.
- **Revisit if:** explicit user request post-1.0.

### D-007: Apple Health on macOS is a stub
- **Decided:** `[health]` tracking type accepts manual entry only on macOS/Linux. Android uses `health_connect` once Phase 4 lands. Real macOS Health bridge is out of scope.
- **Why:** the `health` Dart package is iOS-only; bridging HealthKit on macOS requires native FFI that doesn't fit the timeline.
- **Revisit if:** a user-facing reason emerges to invest in native HealthKit FFI.

---

## 6. How specs evolve

- Specs are PR-reviewable. Behavior changes require a spec edit *first*, then code.
- When code and spec disagree and the code is right, update the spec in the same PR.
- New decisions append to the Decision log above with the next D-NNN id.
- Outdated decisions are not deleted; they're marked `~~superseded by D-NNN~~` so the rationale chain stays auditable.

---

## 7. Definition of done & commit workflow

A phase or feature is **done** when the user explicitly confirms it works as expected — not when the code compiles or tests pass. Tests and analysis are necessary gates; user verification is the sufficient gate.

### After user verification

1. **Tick roadmap checkboxes.** In `specs/roadmap.md`, mark all exit-criteria checkboxes for the verified phase as `[x]`. Add a `**Completed:** YYYY-MM-DD` line at the top of the phase section.
2. **Update any stale specs.** If implementation diverged from a spec (widget name changed, a behaviour was refined), update the relevant spec file to match reality.
3. **Commit all changes.** Stage everything (source, assets, updated specs) and create a git commit. Commit message format:

   ```
   phase N: <one-line summary>

   Verified by user on YYYY-MM-DD.
   Exit criteria: <roadmap.md §Phase N>.
   ```

   Co-author line must be included (see git workflow below).

4. **Tag releases.** At the end of each full phase (not mid-phase features), create an annotated tag: `git tag -a v0.N.0 -m "Phase N complete"`.

### Git commit style

- One commit per verified phase or logical feature unit. Don't commit unverified work.
- Commit message: imperative subject line ≤72 chars, blank line, then body with what changed and the verification note.
- Never `--amend` a commit that has already been shared or tagged.
- Stage files explicitly by name. Never `git add -A` blindly — the build artifacts in `build/` are gitignored but double-check before staging.

### What goes in git

Everything except what `.gitignore` already excludes: source, specs, assets, platform config files (`macos/`, `linux/`, `android/`), `pubspec.yaml`, `pubspec.lock`. The `build/` directory, `.dart_tool/`, and `.pub-cache/` stay out.
