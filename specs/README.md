# Specs — TerminalHabits

Spec-driven development for a Flutter terminal-themed habit tracker, targeting **macOS first**, then Linux, then Android. Local-first; cloud sync deferred to post-1.0.

## Read these in order

1. **[constitution.md](constitution.md)** — principles, non-negotiables, decision log. Start here.
2. **[tech_stack.md](tech_stack.md)** — frameworks, packages, layer architecture.
3. **[data_model.md](data_model.md)** — drift schema, indexes, streak algorithm.
4. **[feature_spec.md](feature_spec.md)** — what the app does and how each feature behaves.
5. **[design_spec.md](design_spec.md)** — tokens, layout (3-pane desktop / 1-pane mobile), themes.
6. **[input_spec.md](input_spec.md)** — keyboard-first desktop and touch-only mobile, unified by Intents.
7. **[build_spec.md](build_spec.md)** — per-platform build, packaging, signing.
8. **[roadmap.md](roadmap.md)** — phased plan with exit criteria.

## Visual reference (not a spec)

[`../FLUTTER_NOTES.md`](../FLUTTER_NOTES.md) — Claude-design-generated notes that map the HTML mockup to Flutter widgets. Treat it as visual scaffolding that informs `design_spec.md`, not as an authoritative behavior contract.

## How specs evolve

- Behavior change → spec edit *before* code edit, in the same PR.
- New dependency → entry in `constitution.md` decision log.
- Past decisions are not deleted; mark them `~~superseded by D-NNN~~`.
- Phase completion → notes in `_phase_logs/phase_N.md` (create as you go).

## Project skeleton (yet to be created)

These specs presume the Flutter project will live alongside the `specs/` folder:

```
Terminal_habits/
├── specs/                ← you are here
├── FLUTTER_NOTES.md      ← visual reference
├── lib/                  ← Flutter source (Phase 0 onward)
├── test/
├── macos/  linux/  android/
├── assets/
├── pubspec.yaml
└── README.md
```

The first command in Phase 0 of [roadmap.md](roadmap.md) generates the project skeleton.
