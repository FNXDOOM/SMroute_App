# SmartRoute — Flutter Client

The native Flutter client for **SmartRoute**, the shared-transit product whose
website is the source of truth. This app is a **client only**: it owns no
backend, no database and no second auth system — every business operation goes
through the existing FastAPI API, exactly like the website does.

```text
                 ┌──────────────────────────┐
                 │ Existing FastAPI backend │  (finalyr_project/backend)
                 │ auth · rides · routing   │
                 │ payments · tracking · WS │
                 └────────────┬─────────────┘
                              │
              ┌───────────────┴───────────────┐
              ▼                               ▼
      Existing website                 This Flutter app
      (frontend/)                      ApiClient — JWT bearer
              └───────────────┬───────────────┘
                              ▼
                    Existing database

Design language:  extracted from frontend/src/index.css + tailwind.config.js
Business rules:   enforced by the backend, never re-implemented here
```

The app is a **map-first** mobile translation of the website: the site's
full-bleed map plus floating booking panel becomes a full-bleed map plus a
draggable bottom sheet.

---

## Screens and flows

| Route | Screen | What it does |
|---|---|---|
| `/` | Bootstrap | Restores the session, then routes to Home or Login |
| `/login` | Sign in | Email + password, or the email-code step for website accounts |
| `/register` | Create account | Registers a passenger against `POST /auth/register` |
| `/home` | Home | Full-bleed live map + draggable booking sheet: pickup, destination, live traffic, ride tiers, one primary CTA, recent rides, active-ride panel |
| `/ride-select` | Location picker | Full-screen map, tap-to-pick (snap-to-road → reverse geocode), address search, confirm sheet — the site's *Choose on map* |
| `/ride-confirm` | Live tracking | Full-bleed map with route + assigned vehicle, camera follows the vehicle while in transit; stage, cancel and actions in a sheet |
| `/trips` | Trips | Real ride history with a trip-detail sheet (fare, H3 cell, vehicle, cancel) |
| `/inbox` | Notifications | Real notifications, filters, mark-one/mark-all read, WebSocket push |
| `/payment` | Payment | Real payment history from `GET /payments/mine` |
| `/profile` | Profile | Name + phone editing (`PATCH /auth/me`), payment history, sign out |
| `/rating` | Post-ride feedback | Star rating, tag chips, optional comment |

**Primary journey** — book, watch, complete:

```text
Home (pickup + destination + tier)  →  POST /rides/request
  → sheet switches to the active-ride panel (6-stage stepper, driver/vehicle)
  → Track live                          →  GET /rides/{id} · /rides/{id}/vehicle
  → vehicle appears                     →  /tracking/ws updates its position
  → status = completed                  →  receipt + feedback
```

---

## Feature status

**Live (real backend + database)**

- Auth: register, login, session restore, logout — local JWT, with a Clerk
  email-code path for accounts created on the website (see *Authentication*).
- Booking: GPS pickup, tap-to-pick pickup/destination, debounced place
  autocomplete, live-traffic routing and ETA, ride request, ride cancel.
- Tracking: ride status polling, assigned-vehicle polling, live vehicle
  position over `/tracking/ws`, follow-camera during `in_progress`.
- Trips and trip detail, notifications (incl. realtime push), payment history,
  profile updates.

**Static by design (no backend counterpart)**

- Ride-tier names, descriptions, ETAs and price ranges come from
  `lib/models/mock_data.dart`. The backend exposes no pricing/quote endpoint.
  Option **IDs must match** the backend's `RIDE_FARES` table
  (`backend/services/razorpay_service.py`) because payment amounts are computed
  server-side from them — the client can never invent a price.

**Not implemented (honest gaps)**

- **Razorpay checkout** — the website pays a fare from the active-ride card via
  `POST /payments/create-order` → checkout → `POST /payments/verify`. The app
  only *reads* payment history; there is no on-device checkout yet.
- **Post-ride feedback** — `POST /rides/{id}/rating` does not exist on the
  backend. The screen is best-effort: a 404 is swallowed and the flow completes,
  so the rating is currently discarded.
- **Driver and admin portals** — the website has role-gated `DriverView`,
  `AdminView` and a driver application flow; this app is passenger-only.
- **Ride tiers on the map style** — the website renders MapLibre from
  `GET /maps/stadia/style.json`, which is auth-protected and whose tile URLs
  need the bearer token, so MapLibre's native tile fetches cannot carry it. The
  app uses a keyless dark CARTO raster style that matches the site's neutral map
  language instead (no map key ships in the binary).

**Deliberately absent** — no mock fallbacks anywhere: a failing backend produces
an error or empty state, never fabricated data. Wallet balances, stored cards
and a "scheduled rides" list were removed because the backend has no such
endpoints and the website has no such features.

---

## Tech stack

| Layer | Choice |
|---|---|
| UI | Flutter (Material 3, dark theme), custom design system |
| State | `provider` (`ChangeNotifier`), no second store |
| Navigation | Named routes with an auth guard in `onGenerateRoute` |
| Map | `flutter_map` ^8.3 (CARTO dark raster tiles, keyless) |
| Location | `geolocator` ^14 (runtime permission, 12 s high-accuracy read) |
| Networking | `http` via `ApiClient` (base URL, JWT header, 15 s timeout) |
| Realtime | `web_socket_channel` → `/tracking/ws` and `/notifications/ws` |
| Auth (web accounts) | `clerk_flutter` (email one-time-code, session JWT) |
| Storage | `shared_preferences` for the bearer token |

---

## Prerequisites

1. **Flutter SDK** 3.x — verify with `flutter doctor`
2. **Android Studio** or VS Code with the Flutter/Dart extensions
3. **A device or emulator** (or a physical phone with USB debugging)
4. **The existing backend running** (`finalyr_project/backend`):
   ```bash
   uvicorn backend.main:app --reload     # http://localhost:8000
   ```

> On the Android emulator, `127.0.0.1` is the emulator itself — use
> `http://10.0.2.2:8000`. On a physical device use your machine's LAN IP or the
> deployed HTTPS origin.

---

## Configuration

The API origin and Clerk key are build-time values, supplied either by
`--dart-define` or by a config file via `--dart-define-from-file`:

| File | Purpose |
|---|---|
| `config.prod.json` | Production build — `https://api.fnxdoom.in` + Clerk key |
| `config.dev.json` | Emulator build — `http://10.0.2.2:8000` + Clerk key |
| `config.local.json` | Machine-specific overrides (gitignored) |

```jsonc
{
  "SMARTROUTE_API_BASE_URL": "https://api.fnxdoom.in",
  "CLERK_PUBLISHABLE_KEY": "pk_test_..."
}
```

| Key | Notes |
|---|---|
| `SMARTROUTE_API_BASE_URL` | API origin. Default `http://127.0.0.1:8000`. |
| `CLERK_PUBLISHABLE_KEY` | Same public key the website ships. Omit it and the app is email/password only (no website-account sign-in). |

**Never present in the app** (backend-only, `backend/.env` or Secrets Manager):
`LOCAL_JWT_SECRET`, `CLERK_SECRET_KEY`, `DATABASE_URL`, `STADIA_API_KEY`,
`RAZORPAY_KEY_SECRET`, `RAZORPAY_WEBHOOK_SECRET`. The Razorpay **Key ID** is
public by design and would only arrive in a `POST /payments/create-order`
response — the app does not need it until checkout is added.

**Backend requirements for website-account sign-in:** `CLERK_ALLOW_NATIVE_CLIENTS=true`
plus a reachable Clerk issuer. Without it the backend rejects native Clerk
tokens and users fall back to email sign-in.

---

## Backend contract

```text
Auth:            Authorization: Bearer <jwt>, Content-Type: application/json
Error format:    {"detail": "<message>"} (FastAPI); 429 adds Retry-After
Token:           local JWT (default 7 days, no refresh — re-login on expiry)
                 or Clerk session JWT (~60 s — re-minted on every app boot)
WebSocket auth:  ?token=<jwt> query param (backend's native-mobile fallback)
Pagination:      notifications limit=1..100; rides/payments capped server-side
Rate limits:     /auth/login 15/5min · /auth/register 5/h · /rides/request 20/min
                 /geocode 60/min · /payments/create-order 10/10min
```

| Feature | Endpoint | Method | Auth | Request | Response | Screen |
|---|---|---|---|---|---|---|
| Register | `/auth/register` | POST | No | `{name,email,phone,password,role:"passenger"}` | `TokenResponse{access_token,user}` | Register |
| Login | `/auth/login` | POST | No | `{email,password}` | `TokenResponse` (401 → Clerk email-code step) | Login |
| Session restore | `/auth/me` | GET | Yes | – | `UserResponse` | Bootstrap |
| Update profile | `/auth/me` | PATCH | Yes | `{name?,phone?}` (email is provider-owned) | `UserResponse` | Profile |
| Search destination | `/geocode/search?query=` | GET | Yes | – | `[{lat,lng,label,raw}]` (India-only) | Booking |
| Autocomplete | `/geocode/suggest?query=&lat=&lng=` | GET | Yes | – | same | Home |
| Book ride | `/rides/request` | POST | Yes | `{pickup_lat/lng,dest_lat/lng,labels,ride_option_*}` | `RideRequestResponse` (201) | Home |
| Trip history | `/rides/my-rides` | GET | Yes | – | `[RideRequestResponse]` | Trips, Home |
| Ride status | `/rides/{id}` | GET | Yes | – | `RideRequestResponse` | Home, tracking |
| Cancel ride | `/rides/{id}` | DELETE | Yes | – | `{status:...}` | Home, tracking, trip detail |
| Assigned vehicle | `/rides/{id}/vehicle` | GET | Yes | – | `VehicleSnapshot` or `null` | Tracking |
| Live tracking | `/tracking/ws?token=` | WS | Yes | – | `{type:"tracking_snapshot"\|"vehicle_location_update",...}` | Tracking |
| Notifications | `/notifications/?limit=100` | GET | Yes | – | `{status,unread_count,notifications[]}` | Inbox, badge |
| Mark all read | `/notifications/read-all` | PATCH | Yes | – | `{status,updated_count}` | Inbox |
| Mark one read | `/notifications/{id}/read` | PATCH | Yes | – | `{status,notification}` | Inbox |
| Notification push | `/notifications/ws?token=` | WS | Yes | – | `{type:"notification",notification:{...}}` | Inbox, ride stages |
| Payment history | `/payments/mine` | GET | Yes | – | `[PaymentResponse]` | Payment |
| Reverse geocode | `/geocode/reverse?lat=&lng=` | GET | Yes | – | `{lat,lng,label}` (India-only) | Map picker / GPS |
| Snap to road | `/routing/nearest-road?lat=&lng=` | GET | Yes | – | `{lat,lng}` | Map picker |
| Road route | `/routing/route?from_lat&from_lng&to_lat&to_lng&traffic` | GET | Yes | – | `{distanceMeters,durationSeconds,geometry:[[lng,lat]]}` | Home, tracking |
| Map style (site) | `/maps/stadia/style.json` | GET | Yes | – | MapLibre style JSON | Not used (see gaps) |

**Endpoint that does not exist:** `POST /rides/{id}/rating` (see *gaps*).

The backend is **India-guarded**: every ride write and geocode lookup outside
the India bounding box is rejected (422). The client mirrors that check for a
clear message but the server stays authoritative.

---

## Authentication

```text
Register / Login → POST /auth/register | /auth/login → {access_token, user}
  → token in SharedPreferences (smartroute_api_token)
  → Authorization: Bearer <jwt> on every request (ApiClient.headers)

Website account (its password lives in Clerk, not in the backend DB)
  → POST /auth/login returns 401 by design
  → clerk_flutter attemptSignIn(emailCode, identifier) emails a 6-digit code
  → user enters the code → attemptSignIn(emailCode, code) verifies it
  → ClerkAuthState.sessionToken().jwt (fresh, short-lived)
  → same ApiClient storage; backend verifies it via Clerk JWKS (RS256)
  → get_or_create_user_from_payload provisions/links the database user

App restart → refresh the Clerk JWT first when one exists (Clerk tokens are
  ~60 s lived, so a stored one is always stale), then GET /auth/me
  → 200: restored · 401/403: token cleared → Login
  → network/5xx: session kept and retried next launch (no forced logout)

Logout → ClerkAuthService.signOut() (Clerk sessions) + token cleared
       + per-account provider state cleared (rides, notifications, payments)
```

This Clerk instance has **password sign-in disabled** — email one-time-code is
its only first factor — which is why the app mirrors the website's code flow
instead of attempting passwords. Accounts created *inside the app* keep using
the fast local-JWT path and never touch Clerk.

---

## Design system

All tokens live in `lib/theme/app_theme.dart` and come from the website:

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

---

## Project structure

```text
lib/
├── main.dart                    # providers, auth guard, eager Clerk init
├── config/app_env.dart          # build-time API URL + Clerk key
├── theme/app_theme.dart         # design tokens + ThemeData
├── models/                      # user, ride_option, ride_request_record,
│                                # ride_stage, assigned_vehicle, notification,
│                                # payment_transaction, mock_data (tier catalogue)
├── providers/                   # auth, ride (booking/polling/tracking),
│                                # notification, payment
├── services/                    # api_client, geocoding, location, routing,
│                                # clerk_auth
├── screens/                     # auth, home, ride, trips, inbox, payment, profile
└── widgets/                     # ui_kit + live_map, bottom_nav_bar,
                                 # ride_option_card, notification_tile
test/widget_test.dart            # widget + provider tests (36)
```

---

## Run, verify, build

```bash
flutter pub get
flutter analyze                     # must report "No issues found!"
flutter test                        # 36 tests

# Run on an emulator against your local backend (or use config.local.json)
flutter run --dart-define-from-file=config.dev.json

# Release build against production, then install on a connected phone
flutter build apk --release --dart-define-from-file=config.prod.json
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

Without `--dart-define-from-file` the app falls back to `http://127.0.0.1:8000`
and has no Clerk key, so website-account sign-in is disabled.

Verify what actually landed in a release binary (replace `/tmp/apkchk` with any
scratch directory):

```bash
python - <<'PY'
import zipfile
z = zipfile.ZipFile('build/app/outputs/flutter-apk/app-release.apk')
z.extract('lib/arm64-v8a/libapp.so', '/tmp/apkchk')
PY
strings /tmp/apkchk/lib/arm64-v8a/libapp.so | grep -c "api.fnxdoom.in"
```

---

## Security review

- No secrets, keys or database credentials ship in the app; the bearer token is
  the only stored credential (`shared_preferences` — use
  `flutter_secure_storage` for a hardened production build).
- Tokens are never logged. Dev request logging prints method/path/status/
  duration only and compiles out of release builds (`kDebugMode`).
- Payment trust boundary respected: all amounts are computed server-side; the
  app never computes or posts an amount.
- 401/403 clears the session; transient network failures do not log anyone out.
- WebSocket auth uses the backend's documented `?token=` mobile fallback.
- Production must be HTTPS/WSS with a non-localhost origin (enforced by the
  config file you build with).

## Reliability behaviour

- 15 s timeout on every request → `ApiException(0)`; transient failures never
  masquerade as "logged out".
- 429 responses surface the backend's `Retry-After` through
  `ApiException.retryAfterSeconds`; the app does not auto-retry.
- Vehicle-assignment polling caps at ~30 attempts (~2 min) — dispatch is
  job-driven and may never assign a vehicle for a given ride, so the UI shows a
  clear "still assigning" state instead of spinning forever.
- Ride-status polling (5 s) is a fallback for the notification socket, so the
  stage machine cannot freeze when the socket is down.
- The tracking socket reconnects up to 5 times with linear backoff; the
  notifications socket up to 3 times (2 s/4 s/6 s).

## Troubleshooting

| Symptom | Fix |
|---|---|
| `flutter: command not found` | Add Flutter's `bin` to `PATH` |
| `No devices found` | Start an emulator, or enable USB debugging and re-run `adb devices` |
| `Gradle build failed` | `flutter clean && flutter pub get` |
| Requests fail on a physical phone | You are probably pointing at `127.0.0.1`; rebuild with your LAN IP or the production origin |
| "Sign-in did not complete" | The Clerk key is missing from the build config, or the backend lacks `CLERK_ALLOW_NATIVE_CLIENTS=true` |
| Blank map | Tile host unreachable from the device; the map falls back to the app's neutral surface colour |

## License

Educational / portfolio use.
