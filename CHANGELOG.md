# Changelog

All notable changes to this project are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **Carpool** — per-rider lifecycle stages and the pooled route on both maps:
  riders see the optimized route leg by leg with their own legs highlighted;
  the driver console names the rides at each stop and calls out the next stop.
- **Driver presence** — the console beats the dispatch availability signal, so
  the backend keeps offering runs to an open console.
- **Road-projected vehicle motion** — GPS fixes within 65 m of the route
  polyline snap onto it, with a 200 m jump guard and eased heading turns
  (`lib/services/route_trace.dart`, `lib/services/passenger_motion.dart`).
- Gitleaks pre-commit guard in the backend repository to block committed
  credentials.

### Changed

- Documentation restructured into `docs/` (backend contract, screens/flows,
  design system, maps, live animation, security/reliability, endpoint RFC); the
  README is now an overview plus quick start.
- Security audit findings consolidated into `docs/security-and-reliability.md`
  with per-finding status and re-verification results.
- Licensing is now explicit: Apache-2.0 `LICENSE` with a `NOTICE` covering
  third-party packages and map-provider attribution.

### Fixed

- **Security:** the session token moved from plaintext `SharedPreferences` to
  Keystore/Keychain-backed secure storage; existing tokens migrate on first
  launch and the plaintext copy is deleted.
- **Security:** Android backups and device-to-device transfer are disabled
  (`allowBackup="false"` plus backup/data-extraction rules), so a bearer token
  cannot leave the device through a backup.
- **Security:** an unapproved driver can no longer enter the console —
  `driver_status` is read, not just `role`.
- **Security:** the tracking socket stops reconnecting after the server closes
  it with `4403` (access revoked) and hands off to the REST position poll.
- Ride state is guarded against async races: a stale status poll cannot write
  onto a rebooked ride, and logout clears the previous account's trip.
- Abandoned Razorpay checkouts settle correctly instead of leaving the fare
  stuck, and the wallet event type is fixed.
- The vehicle position falls back to a REST poll once the tracking socket's
  reconnect budget is spent.
- Invalid ride coordinates are rejected client-side and offline errors surface
  instead of a spinner.
- Map tile probing is cached per origin and its HTTP clients are closed.
- Route and payment state recover from updates that arrive out of order.
- Android cleartext is permitted only in debug builds for the dev hosts
  (`10.0.2.2`, `localhost`, `127.0.0.1`); release builds keep the platform
  default of blocking it.

### Removed

- The post-ride rating screen. The backend has no rating model, route or column;
  the screen posted to `POST /rides/{id}/rating`, discarded the resulting 404 and
  thanked the rider for feedback that was never stored.
- Dead repository artifacts (`.gitkeep` placeholders, local DevTools state,
  scratch tooling).

### Security

Backend counterpart fixes: email changes now require the current password, demo
endpoints are disabled outside development, and demand-prediction endpoints
require an admin or active driver. See `docs/security-and-reliability.md`.

## [1.0.0] - 2026-09-18

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
  `/tracking/ws`, and a follow-camera during `in_progress`.
- **Driver console** (role-gated) — vehicle auto-selection, on/off duty, GPS
  position push, dispatch board, and accept → arriving → in progress →
  completed.
- **Driver apply** — `POST /auth/driver/apply` with license plate, reachable
  from Profile.
- **Payments** — Razorpay checkout with server-side signature verification and
  server-authoritative payment history.
- **Trips, inbox, profile** — real ride history with trip detail, notifications
  with read state, name/phone editing.
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
- Branding renamed to **Smroute** with new launcher icons.

### Fixed

- Impeller disabled on Android to avoid render-surface crashes on some
  Android 13 devices.
- Navigation hardened: bounded tab stack, double-back to exit, predictive back,
  and layout-overflow guards.
- The ride-tier payment option renders on the home screen again.

### Security

- No secrets or credentials ship in the app; the Razorpay Key Secret never
  reaches the client and all amounts are computed server-side.
- Tokens are never logged; dev request logging compiles out of release builds.

## 0.1.0 - 2026-08-02

Initial scaffold: theme and design tokens, core models, `ApiClient`,
screens/providers/widgets for the main flows, and the Android project.

[Unreleased]: https://github.com/FNXDOOM/SMroute_App/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/FNXDOOM/SMroute_App/releases/tag/v1.0.0
