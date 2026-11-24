# Design system

All tokens live in `lib/theme/app_theme.dart` and come from the website
(`frontend/src/index.css` + `tailwind.config.js`):

| Token | Value |
|---|---|
| Canvas / surface / nested | `#000000` / `#1F1F1F` / `#2A2A2A` |
| Hairline border / strong | `#333333` / `#545454` |
| Text primary / secondary / subtle | `#FFFFFF` / `#AFAFAF` / `#8A8A8A` |
| Primary action (dark theme) | white background, black text |
| Accent (status only) | `#276EF1` (completed) |
| Error / warning | `#D93025` / `#F5A623` |
| Radii | 6 · 8 · 12 · 16 |
| Spacing | 4 · 8 · 12 · 16 · 20 · 24 · 32 · 48 · 64 (gutter 20) |
| Shadows | `0 2px 8px 8%` · `0 8px 24px 12%` (floating surfaces only) |
| Type | Inter metrics — 15 px body, −0.01/−0.02 em tracking, 11 px eyebrows at +0.08 em, tabular numerals |
| Motion | 120 ms (press) · 180 ms (state) · 260 ms (sheet) · 420 ms (map camera) |

`lib/widgets/ui_kit.dart` holds the components so screens never hand-roll
colours, radii or type: `AppCard`, `AppButton`, `AppField`, `PlaceField`,
`MapFirstScaffold`, `AppDraggableSheet`, `SheetPanel`/`SheetHeader`,
`StatusBadge`, `RouteLeg`, `ListRow`, `SegmentedTabs`, `StarRating`, `AppChip`,
`EmptyState`, `SkeletonRows`, `RideStageStepper`, `PressableScale`.

Loading uses skeletons rather than spinners; empty states are first-class; ride
progress is defined once in `lib/models/ride_stage.dart` (the site's six stages)
so every screen shows the same step for the same backend status.
