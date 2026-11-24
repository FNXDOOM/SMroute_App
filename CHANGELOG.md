# Changelog

All notable changes to this project are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Road-projected live vehicle motion: GPS fixes within 65 m of the route
  polyline snap onto it, so the marker follows the street instead of drifting
  with the raw signal (`lib/services/route_trace.dart`,
  `lib/services/passenger_motion.dart`).
- Guard against backwards/jumpy fixes (200 m bound) and eased heading turns.
- Gitleaks pre-commit guard in the backend repository to block committed
  credentials.

### Changed

- Documentation restructured into `docs/` (backend contract, screens/flows,
  design system, maps, live animation, security/reliability, endpoint RFC);
  the README is now an overview plus quick start.
- Security audit findings folded into `docs/security-and-reliability.md` with
  per-finding status and re-verification results.

### Fixed

- **Security:** the session token now lives in Keystore/Keychain-backed secure
  storage instead of plaintext `SharedPreferences`; existing tokens migrate on
  first launch and the plaintext copy is deleted.
- **Security:** Android backups and device-to-device transfer are disabled
  (`allowBackup="false"` plus backup/data-extraction rules), so a bearer token
  cannot leave the device through a backup.
- Tracking socket no longer reconnects after the server closes it with `4403`
  (access revoked); it hands off to the REST position poll instead of hammering
  a refused door.
- Removed dead repository artifacts (`.gitkeep` placeholders, local DevTools
  state, scratch tooling) and gave `pubspec.yaml` a real description.

### Security

Backend counterpart fixes (in the SmartRoute backend repository): email changes
now require the current password, demo endpoints are disabled outside
development, and demand-prediction endpoints require an admin or active driver.
See `docs/security-and-reliability.md`.

## [1.0.0] — 2026-11-17

First complete client release, tracking the website feature-for-feature.

### Added

- **Auth** — register, login, session restore and logout on the backend's local
  JWT, plus a Clerk email one-time-code path for accounts created on the
  website. Clerk session tokens are resolved per request with a coalesced
  refresh and a single 401 retry.
- **Booking** — GPS pickup, tap-to-pick on the map (snap-to-road then reverse
  geocode), debounced place autocomplete, live-traffic routing and ETA, ride
  tiers, ride request and cancellation.
- **Live tracking** — six-stage stepper, assigned vehicle, position over
  `/tracking/ws` with a REST fallback poll, and a follow-camera during
  `in_progress`.
- **Pooled rides** — per-rider carpool stages and the optimized shared route
  drawn leg by leg, with the rider's own legs highlighted and numbered stop pins.
- **Driver console** (role-gated) — vehicle auto-selection, on/off duty, GPS
  position push, dispatch board, accept → arriving → in progress → completed,
  and the assigned pooled route with a next-stop callout.
- **Driver apply** — `POST /auth/driver/apply` with license plate, reachable
  from Profile.
- **Payments** — Razorpay checkout with server-side signature verification,
  pending/authorized reconciliation through `GET /payments/mine`, and payment
  history.
- **Trips, inbox, profile** — real ride history with trip detail, notifications
  with WebSocket push and read state, name/phone editing.
- **Maps** — the website's Stadia dark basemap through the backend's
  authenticated tile proxy, with a brightened keyless CARTO fallback selected
  by a probe tile.
- **Design system** — the website's tokens (canvas, surfaces, hairlines, type,
  spacing, radii, motion) and a shared `ui_kit` so screens never hand-roll
  styles.

### Changed

- Map-first layout throughout: full-bleed map with a draggable bottom sheet,
  matching the website's map plus floating panel.
- Ride progress is defined once (`lib/models/ride_stage.dart`) so every screen
  shows the same step for the same backend status.

### Fixed

- Android cleartext is permitted only in debug builds for the dev hosts
  (`10.0.2.2`, `localhost`, `127.0.0.1`); release builds keep the platform
  default of blocking it.
- Impeller disabled on Android to avoid render-surface crashes on some
  Android 13 devices.
- Navigation hardened: bounded tab stack, double-back to exit, predictive back,
  and layout-overflow guards.
- An unapproved driver can no longer enter the driver console
  (`driver_status` is read, not just `role`).

### Removed

- The post-ride rating screen. The backend has no rating model, route or column;
  the screen posted to `POST /rides/{id}/rating`, discarded the resulting 404 and
  thanked the rider for feedback that was never stored.

### Security

- No secrets or credentials ship in the app; the Razorpay Key Secret never
  reaches the client and all amounts are computed server-side.
- Tokens are never logged; dev request logging compiles out of release builds.

## [0.1.0] — 2026-08-02

Initial scaffold: theme and design tokens, core models, `ApiClient`,
screens/providers/widgets for the main flows, and the Android project.

[Unreleased]: https://github.com/FNXDOOM/SMroute_App/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/FNXDOOM/SMroute_App/compare/v0.1.0...v1.0.0
