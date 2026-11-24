# Security, reliability, troubleshooting

## Security review

- No secrets, keys or database credentials ship in the app; the bearer token is
  the only stored credential, held in Keystore/Keychain-backed secure storage
  (`flutter_secure_storage`) rather than plaintext app data. Android backups
  are disabled (`allowBackup="false"` + backup/data-extraction rules), so the
  token cannot leave the device through a backup or adb extraction.
- Tokens are never logged. Dev request logging prints method/path/status/
  duration, the token's remaining lifetime (decoded from the `exp` claim only)
  and whether the request was retried — never the token itself or the
  Authorization header — and compiles out of release builds (`kDebugMode`).
- Payment trust boundary respected: all amounts are computed server-side; the
  app never computes or posts an amount.
- 401/403 clears the session; transient network failures do not log anyone out.
- WebSocket auth uses the backend's documented `?token=` mobile fallback.
  The tracking socket is closed by the server with code **4403** when access is
  revoked; the app treats that as terminal and falls back to REST polling (see
  [backend contract](./backend-contract.md#tracking-socket-revocation)).
- Production must be HTTPS/WSS with a non-localhost origin (enforced by the
  config file you build with).
- Cleartext HTTP is permitted only in debug builds for `10.0.2.2`, `localhost`
  and `127.0.0.1` (`network_security_config.xml` in the debug manifest); release
  builds keep the platform default of blocking it.

## Security audit (2026-11-24)

Static review of the app and the FastAPI backend, plus dynamic testing against a
disposable local PostGIS instance with synthetic accounts (no production or
third-party systems). **Verdict: conditional go** — no Critical/High exploitable
holes in the API surface.

**Verified as not vulnerable** (real requests, two accounts):

| Test | Result |
|---|---|
| IDOR — read/cancel/status-change another user's ride (`/rides/{id}`, `/vehicle`, `/route`, DELETE, PATCH) | 403/404 every time |
| IDOR — payments (`/payments/{id}`, order for someone else's ride) | 404/400, ownership enforced |
| Unauthenticated access to rides/jobs/analytics/admin | 401 everywhere |
| Driver-only endpoints as a passenger | 403 |
| Register with `role:"admin"` | forced to `passenger` |
| JWT `alg=none`, wrong-secret, garbage | 401 |
| Login rate limit | 429 after the limit, keyed on the real client IP (not spoofable XFF); per-user limits on payments |
| Maps proxy path traversal (`../`, `%2f`) | rejected |
| WebSocket without/bad token | 403 |
| Razorpay webhook bad signature | 400; amounts server-side; authorized ≠ captured |
| Ride outside India | 422 geofence |
| SQL injection surface | SQLAlchemy ORM / bound `text()` params only |

**Findings and their status:**

| ID | Finding | Status |
|---|---|---|
| F1 | Backend secrets in a plaintext `backend/.env` (Supabase password, Clerk secret, `LOCAL_JWT_SECRET`, Razorpay, Stadia) | **Rotate the values** in each provider dashboard and mint a new `LOCAL_JWT_SECRET`. The file is gitignored; a gitleaks pre-commit hook now prevents committing credentials. |
| F2 | Bearer token in plaintext storage + Android backup enabled | **Fixed** — secure storage, legacy token migrated and deleted, backups disabled. |
| F2b | 7-day local JWT has no server-side revocation (logout is client-side only) | **Open** — a `jti` denylist or shorter `LOCAL_JWT_EXPIRES_MINUTES` closes it. |
| F3 | Email change without re-authentication | **Fixed** — `PATCH /auth/me` requires `current_password` for a local account; Clerk-owned accounts cannot change email there. |
| F4 | Demo and demand-prediction endpoints ungated | **Fixed** — demo endpoints refuse non-admins when `APP_ENV=production` (still work in development); `/predict/*` requires admin or an active driver. |
| F5 | No TLS certificate pinning | **Open (accepted)** — hardening item; needs a pinned certificate set. |

Re-verified after the fixes: email change returns 403 without/wrong password and
200 with it; demo endpoints 403 in production but 201 in development; `/predict`
403 for passengers; unauthenticated, `alg=none` and cross-user requests still
401/404. The Flutter suite passes 168/168 and the backend suite is unchanged
from its pre-change baseline.


## Reliability behaviour

- 15 s timeout on every request → `ApiException(0)`; transient failures never
  masquerade as "logged out".
- 429 responses surface the backend's `Retry-After` through
  `ApiException.retryAfterSeconds`; the app does not auto-retry.
- Session tokens are resolved per request, so a short-lived Clerk JWT (~60 s)
  can't go stale mid-session. A 401 is answered with one fresh-token retry; if
  the refresh returns the same token the 401 is surfaced instead of looping.
- The map's authenticated tile proxy and both WebSockets (notifications,
  tracking) also read the current token at connect/request time, so they can't
  sit on an expired one.
- Vehicle-assignment polling caps at ~30 attempts (~2 min) — dispatch is
  job-driven and may never assign a vehicle for a given ride, so the UI shows a
  clear "still assigning" state instead of spinning forever.
- Ride-status polling (5 s) is a fallback for the notification socket, so the
  stage machine cannot freeze when the socket is down.
- The tracking socket reconnects up to 5 times with linear backoff, then hands
  off to the REST position poll; the notifications socket reconnects up to
  3 times (2 s/4 s/6 s).

## Troubleshooting

| Symptom | Fix |
|---|---|
| `flutter: command not found` | Add Flutter's `bin` to `PATH` |
| `No devices found` | Start an emulator, or enable USB debugging and re-run `adb devices` |
| `Gradle build failed` | `flutter clean && flutter pub get` |
| Requests fail on a physical phone | You are probably pointing at `127.0.0.1`; rebuild with your LAN IP or the production origin |
| "Sign-in did not complete" | The Clerk key is missing from the build config, or the backend lacks `CLERK_ALLOW_NATIVE_CLIENTS=true` |
| Map is completely black | Tiles can't be fetched *and* the fallback is dark. Check `adb logcat \| grep "HTTP request failed"` — 401 means the token wasn't accepted by `/maps/stadia/resource`, 404/500 means the backend proxy (see [maps](./maps.md)) |
| Map loads but looks empty/flat | You are on the brightened CARTO fallback: the app couldn't reach the backend tile proxy. Confirm the token is valid and the backend's `STADIA_API_KEY` is set |
