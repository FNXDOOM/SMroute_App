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

## Features

- **Booking** — GPS pickup, tap-to-pick on the map, place autocomplete,
  live-traffic routing and ETA, ride tiers, one-tap request, cancel.
- **Live tracking** — ride-stage stepper, assigned vehicle, position over
  `/tracking/ws` snapped onto the road polyline, follow-camera in transit.
- **Pooled (shared) rides** — the backend's optimized route drawn leg by leg,
  with your own legs highlighted; the driver console shows the next stop.
- **Payments** — Razorpay checkout with server-side verification; an
  authorized-but-not-captured payment reconciles via `/payments/mine`.
- **Driver console** (role-gated) — duty toggle, GPS push, dispatch board,
  accept → arriving → in progress → completed.
- **Notifications & trips** — real inbox with WebSocket push, full ride
  history with per-trip detail.

No mock fallbacks anywhere: a failing backend produces an error or empty
state, never fabricated data. See [docs/screens-and-flows.md](docs/screens-and-flows.md)
for the full route map and the honest list of gaps.

## Tech stack

| Layer | Choice |
|---|---|
| UI | Flutter (Material 3, dark theme), custom design system |
| State | `provider` (`ChangeNotifier`), no second store |
| Navigation | Named routes with an auth guard in `onGenerateRoute` |
| Map | `flutter_map` ^8.3 (Stadia `alidade_smooth_dark` via the backend proxy; keyless CARTO fallback) |
| Location | `geolocator` ^14 (runtime permission, 12 s high-accuracy read) |
| Networking | `http` via `ApiClient` (base URL, JWT header, 15 s timeout) |
| Realtime | `web_socket_channel` → `/tracking/ws` and `/notifications/ws` |
| Auth (web accounts) | `clerk_flutter` (email one-time-code, session JWT) |
| Storage | `shared_preferences` for the bearer token |

## Quick start

**Prerequisites**

1. **Flutter SDK** 3.x — verify with `flutter doctor`
2. **Android Studio** or VS Code with the Flutter/Dart extensions
3. **A device or emulator** (or a physical phone with USB debugging)
4. **The existing backend running** (`finalyr_project/backend`) — its imports are
   flat, so uvicorn must run from inside `backend/` (or use the project-root
   `main.py`, which puts `backend/` on `sys.path`):
   ```bash
   cd finalyr_project/backend
   uvicorn main:app --reload --port 8000   # http://localhost:8000
   ```
   `uvicorn backend.main:app` fails with `ModuleNotFoundError: No module named 'database'`.

> On the Android emulator, `127.0.0.1` is the emulator itself — use
> `http://10.0.2.2:8000`. On a physical device use your machine's LAN IP or the
> deployed HTTPS origin.

**Configuration**

The API origin and Clerk key are build-time values, supplied either by
`--dart-define` or by a config file via `--dart-define-from-file`:

| File | Purpose |
|---|---|
| `config.prod.json` | Production build — `https://api.fnxdoom.in` + Clerk key (gitignored) |
| `config.dev.json` | Emulator build — `http://10.0.2.2:8000` + Clerk key |
| `config.local.json` | Machine-specific overrides (gitignored) |
| `config.prod.example.json` | Template to copy for a production build |

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
public by design and arrives only inside a `POST /payments/create-order`
response — the app needs no key material to run checkout.

**Backend requirements for website-account sign-in:** `CLERK_ALLOW_NATIVE_CLIENTS=true`
plus a reachable Clerk issuer. Without it the backend rejects native Clerk
tokens and users fall back to email sign-in.

**Run, verify, build**

```bash
flutter pub get
flutter analyze                     # must report "No issues found!"
flutter test                        # 168 tests

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

Launcher icons are generated from `assets/branding/smroute_icon.png`:

```bash
python scripts/make_icons.py
```

## Project structure

```text
lib/
├── main.dart                    # providers, auth guard, eager Clerk init
├── config/app_env.dart          # build-time API URL + Clerk key
├── theme/app_theme.dart         # design tokens + ThemeData
├── models/                      # user, ride_option, ride_request_record,
│                                # ride_stage, carpool_stage, assigned_vehicle,
│                                # notification, payment_transaction,
│                                # shared_route, vehicle_animation, mock_data
├── providers/                   # auth, ride (booking/polling/tracking/payments),
│                                # driver, notification, payment
├── services/                    # api_client, geocoding, location, routing,
│                                # map_tiles (basemap), route_trace + passenger_motion
│                                # (fix → road projection), razorpay, driver,
│                                # carpool, clerk_auth, ride_vehicle_animation
├── screens/                     # auth, home, ride, trips, inbox, payment,
│                                # profile, driver (console, run, apply)
└── widgets/                     # ui_kit + live_map, bottom_nav_bar, carpool
                                 # panels/stepper/stop list, fare_payment_panel
test/                            # 168 widget, provider, model and motion tests
├── widget_test.dart             # screens, providers, ride lifecycle, payments
├── route_trace_test.dart        # road projection (new)
├── shared_route_test.dart       # pooled route, next stop, leg rendering
├── live_map_motion_test.dart    # vehicle walk, retarget, fix snapping
├── vehicle_animation_test.dart  # ride status → animated path
└── ...                          # contract, carpool, razorpay, guards
```

## Documentation

| Doc | Contents |
|---|---|
| [docs/screens-and-flows.md](docs/screens-and-flows.md) | Route map, primary journey, feature status, honest gaps |
| [docs/backend-contract.md](docs/backend-contract.md) | Auth flows, endpoint table, payment trust boundary, socket revocation |
| [docs/design-system.md](docs/design-system.md) | Colour/type/spacing/motion tokens, `ui_kit` components |
| [docs/maps.md](docs/maps.md) | Basemap resolution (Stadia proxy vs CARTO fallback), known backend issue |
| [docs/live-ride-animation.md](docs/live-ride-animation.md) | Status-derived vehicle animation, route projection, motion mechanics |
| [docs/security-and-reliability.md](docs/security-and-reliability.md) | Security review, reliability behaviour, troubleshooting |
| [docs/rfc-endpoint-registry.md](docs/rfc-endpoint-registry.md) | Proposed typed endpoint catalog (design RFC) |

## License

Educational / portfolio use.
