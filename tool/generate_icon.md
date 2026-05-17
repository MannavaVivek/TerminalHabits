# App icon generation

## What to create

Two PNG files at `assets/icon/`:

| File | Size | Description |
|------|------|-------------|
| `icon.png` | 1024×1024 | Full icon (used for non-adaptive fallback) |
| `icon_foreground.png` | 1024×1024 | Foreground layer only (transparent bg) |

## Design spec (from `design_spec.md` §9)

- Background: `#0B1014` (TH.bg)
- Foreground: monogram text `i.H` in `#5CE39A` (TH.green / Matrix accent)
- Font: JetBrains Mono SemiBold
- Text centered, ~400sp, occupying ~60% of the canvas

## Steps

1. Open Figma (or any vector tool) and create a 1024×1024 frame.
2. Fill the background with `#0B1014`.
3. Add centered text `i.H` in JetBrains Mono SemiBold at ~400sp, color `#5CE39A`.
4. Export `icon.png` (both layers) and `icon_foreground.png` (text on transparent bg).
5. Place both in `assets/icon/`.
6. Run: `dart run flutter_launcher_icons`

The `flutter_launcher_icons` config in `pubspec.yaml` will generate all required
mipmap sizes and the adaptive icon layers automatically.
