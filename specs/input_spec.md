# Input Spec — TerminalHabits

> Two input modalities, one intent layer. Desktop is keyboard-first; Android is touch-only. Both dispatch into the same `Intent`/`Action` system so feature behavior is identical.

This is the doc that resolves the desktop-vs-mobile divergence the constitution allows. Read [constitution.md](constitution.md) §3 for the divergence policy first.

---

## 1. The unifying abstraction: Intents

All user actions — desktop or mobile — funnel through Flutter's `Intent`/`Actions` system. Define one `Intent` per logical action; bind it to keyboard shortcuts on desktop and to touch widgets on mobile.

```dart
// shortcuts/intents.dart

class GoToIntent extends Intent {
  final ViewName view;
  const GoToIntent(this.view);
}

class NewHabitIntent extends Intent { const NewHabitIntent(); }
class ToggleFocusedHabitIntent extends Intent { const ToggleFocusedHabitIntent(); }
class FocusNextHabitIntent extends Intent { const FocusNextHabitIntent(); }
class FocusPrevHabitIntent extends Intent { const FocusPrevHabitIntent(); }
class OpenPaletteIntent extends Intent { const OpenPaletteIntent(); }
class OpenSettingsIntent extends Intent { const OpenSettingsIntent(); }
class StartVacationIntent extends Intent { const StartVacationIntent(); }
class ArchiveFocusedHabitIntent extends Intent { const ArchiveFocusedHabitIntent(); }
class EditFocusedHabitIntent extends Intent { const EditFocusedHabitIntent(); }
class CommandIntent extends Intent {
  final Command command;        // sealed-class output of the parser
  const CommandIntent(this.command);
}
```

Both `Sidebar` items (clickable) and `Cmd+1` keyboard shortcut dispatch `GoToIntent('daily')`. The `Action` handler is registered once at the app root; both code paths flow through it.

**Rule:** if an action is reachable from desktop, it must also be reachable on mobile. No keyboard-only commands. The mapping table in §3.3 enforces this.

---

## 2. Desktop input (macOS, Linux)

### 2.1 Keyboard shortcut table

`Cmd` on macOS, `Ctrl` on Linux. Resolved at runtime via `defaultTargetPlatform`.

| Shortcut | Intent | Scope |
|---|---|---|
| `Cmd+K` | `OpenPaletteIntent` | global |
| `:` (Shift+`;`) | `OpenPaletteIntent` | global, when no text field is focused |
| `Cmd+1` | `GoToIntent('daily')` | global |
| `Cmd+2` | `GoToIntent('stats')` | global |
| `Cmd+3` | `GoToIntent('profile')` | global |
| `Cmd+N` | `NewHabitIntent` | global |
| `Cmd+,` | `OpenSettingsIntent` | global |
| `Cmd+V` | `StartVacationIntent` | global |
| `j` / `↓` | `FocusNextHabitIntent` | DailyView only |
| `k` / `↑` | `FocusPrevHabitIntent` | DailyView only |
| `space` | `ToggleFocusedHabitIntent` | DailyView only |
| `e` | `EditFocusedHabitIntent` | DailyView only |
| `a` | `ArchiveFocusedHabitIntent` | DailyView only |
| `Esc` | dismiss modal / unfocus | global modal-aware |
| `Enter` | confirm primary action in dialog | dialog scope |

**Conflicts:** `j/k/space/e/a` are bare keys; they only fire when no text field has focus. Use `Focus` and `FocusNode.skipTraversal` in DailyView so the habit-list owns these keys when the user is not typing.

### 2.2 Command palette

- Activator: `Cmd+K` or `:`.
- Dialog: top-aligned, `barrierColor: black54`, 110px from top, 480px wide.
- Behavior:
  - Live-filter the registered command list as the user types.
  - Up/Down arrow nav, Enter dispatches.
  - Esc dismisses without dispatch.
  - Empty input shows recent commands (last 5).
  - Unknown command (typed exactly) shows error inline `unknown: ${input}` and disables Enter.

### 2.3 Command grammar (parsed by `domain/commands.dart`)

The palette accepts both natural-language commands and terse forms.

```
new                                  → NewHabit
new <name>                           → NewHabit (prefilled)
:                                    → opens palette (no-op when already open)
daily | stats | profile              → GoTo(view)
1 | 2 | 3                            → GoTo(daily|stats|profile)
check <id>                           → ToggleHabit(id)
check --id 5                         → ToggleHabit(5)
edit <id>                            → EditHabit(id)
archive <id>                         → ArchiveHabit(id)
vacation <days>                      → StartVacation(days)
vacation end                         → EndVacation
theme <name>                         → SetTheme(name)
font size <xs|sm|md|lg>              → SetFontSize(size)
export                               → Export
import                               → Import (opens file picker)
quit                                 → Quit (desktop only)
```

The grammar is implemented as a sealed-class hierarchy + a parser that returns `Command?`. The parser is unit-tested with one test per grammar line above.

### 2.4 Focus model on DailyView

- DailyView owns a `focusedHabitIndex` (Riverpod `StateProvider<int?>`).
- On view enter: `focusedHabitIndex = 0` if there are habits, else `null`.
- `j/k`/arrows mutate the index, clamped to `[0, habits.length - 1]`.
- The focused row visually shifts: `border` color → `TH.line2`, leftmost char becomes `›` instead of space.
- Clicking a row also sets the focus.

---

## 3. Mobile input (Android)

### 3.1 Top-level navigation

- **Bottom tab bar** with three tabs: Daily / Stats / Profile.
- Tab bar uses bordered chips (no Material indicator). Active tab: `border: TH.green`, inactive: `border: TH.line`.
- Tap tab → `GoToIntent` dispatch (same handler as desktop).
- No hamburger, no drawer. Three tabs only.

### 3.2 The `MobileCommandBridge`

Replaces the desktop command palette. A `GridView` of bordered command buttons.

- Triggered by a floating `[ + ]` button in the bottom-right of every view, *except* during onboarding and inside modals.
- When opened, takes over the full screen as a modal route (`PageRouteBuilder` with no transition).
- Header: `> command` prompt line.
- 2-column grid on phones, 3-column on tablets (Phase 9 stretch).
- Each cell: bordered box, monospace label, single-line description.
- Tap → dispatches the corresponding `Intent`, then pops the bridge.

**Cell catalog (Phase 9 minimum):**

| Cell label | Dispatched Intent |
|---|---|
| `[ new ]` | `NewHabitIntent` |
| `[ daily ]` | `GoToIntent('daily')` |
| `[ stats ]` | `GoToIntent('stats')` |
| `[ vacation ]` | `StartVacationIntent` |
| `[ settings ]` | `OpenSettingsIntent` |
| `[ export ]` | `CommandIntent(Export())` |
| `[ themes ]` | sub-grid of 6 theme cells |
| `[ fonts ]` | sub-grid of font-size + family cells |

The bridge is *generated* from the same registry that powers the palette. Adding a new command in one place adds it in both.

### 3.3 Touch affordances on Daily view

| Gesture | Result |
|---|---|
| Tap habit row | toggle (checkbox) / open inline counter (count, number) / open value input (health) |
| Long-press habit row | open context menu sheet (edit / archive / move up / move down / delete) |
| Swipe-right on habit row | open quick-edit dialog |
| Swipe-left on habit row | toggle archive (with undo snackbar — but use bordered toast, not Material `SnackBar`) |
| Tap `[ + ]` FAB | open `MobileCommandBridge` |
| Pull-down at top | refresh streaks (recompute) |
| Swipe up from bottom edge | open Inspector bottom-sheet |

### 3.4 Inspector as bottom sheet

On mobile, the desktop right-pane Inspector becomes a draggable bottom sheet.

- Trigger: swipe-up from bottom or tap the `[ ⌃ ]` chip on the status edge.
- Sheet height: 40% screen at rest, 90% expanded.
- Content: same as desktop inspector, see [feature_spec.md](feature_spec.md) §10.
- Dismiss: swipe-down or tap outside.

### 3.5 Haptic feedback policy

Use `HapticFeedback` from `services` (no extra package needed):

| Event | Haptic |
|---|---|
| Habit toggle (any tracking type) | `lightImpact` |
| Long-press to open context menu | `mediumImpact` |
| Theme switch | `selectionClick` |
| Command bridge cell tap | `lightImpact` |
| Destructive action confirm (delete) | `heavyImpact` |
| Errors (invalid command, etc.) | `vibrate` (single short) |

Haptics fire only on Android. On desktop they're no-ops.

### 3.6 Tap target sizes

- Minimum 48×48 dp for any interactive element (Material guideline; we don't use Material widgets but the size threshold stands).
- Habit rows: 56dp minimum height.
- Bottom tab bar: 64dp height.
- Command bridge cells: 88dp height.

These minima are enforced via `ConstrainedBox` in widgets, not by Material defaults.

### 3.7 Text input on mobile

Bringing up the soft keyboard is rare in this app. The cases where it appears:

- New habit dialog (name, note, target, unit).
- Settings → user name, default group.
- Onboarding step 1.
- Search-as-filter in command bridge if the user wants to type (optional Phase 9 stretch).

We do **not** offer a text-typed command interface on mobile. Touch-only per the user's spec.

---

## 4. Shared behaviors (both platforms)

### 4.1 Modals and `Esc` / back

- Desktop: `Esc` closes the topmost modal.
- Android: hardware/gesture back closes the topmost modal. If no modal, the back gesture pops the navigation stack; from a top-level tab, it minimizes the app (don't intercept).

### 4.2 Focus traversal across modals

When a modal opens, focus moves into it. When closed, focus returns to the previously focused element. Use `FocusScope` per route; this is mostly free with Flutter's `Navigator`.

### 4.3 Disabled input

- Inside a vacation, all habit toggles still work but the row visually dims and the streak engine ignores those completions.
- During import, all input is blocked with a centered status message until the import completes.

### 4.4 Unknown / invalid input

- Desktop: shown inline in the palette, no toast.
- Mobile: shown as a bordered toast that auto-dismisses in 2.5s.

Toast widget is custom; never use Material `SnackBar`.

---

## 5. Accessibility minimums

- All interactive widgets have `Semantics` labels matching their visible text.
- Color is **never** the only signal (e.g., completed habit shows `[✓]` *and* a color shift).
- Font size pill `lg` (15sp) is the upward bound; users needing larger text use OS-level zoom.
- Screen-reader users get the same actions via Semantics; we don't ship a separate screen-reader UX in v1.
- High-contrast theme: `Mono` theme satisfies this — list it as the recommended a11y theme in Settings copy.

---

## 6. Testing the input layer

| Layer | Test |
|---|---|
| Command parser | Unit test, one per grammar line in §2.3. |
| Intent dispatch | Riverpod container test: dispatching a `GoToIntent` mutates the navigation provider. |
| Keyboard shortcuts | Widget test with `WidgetTester.sendKeyEvent` for each global shortcut. |
| Mobile gestures | Widget test using `gestureLongPress`, `flingFrom`. |
| Cross-platform parity | Integration test: same scripted action sequence runs on macOS and Android emulator and produces the same DB state. |
