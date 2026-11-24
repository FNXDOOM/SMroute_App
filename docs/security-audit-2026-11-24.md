# Security audit — 2026-11-24

**Scope:** the Flutter client (`finalyr_app`, this repo) and the FastAPI backend +
deployment config (`C:\Users\gudiy\Music\finalyr_project`). Own project, tested
against a **local disposable instance only** (dockerized PostGIS, synthetic
accounts `attacker.a@test.local` / `victim.b@test.local`). No production or
third-party systems were probed.

**Method:** static review of both repos + live dynamic testing of the backend
(register/login, IDOR battery across rides/payments/notifications, JWT forgery,
WebSocket auth, rate limiting, geofence, maps proxy) using two synthetic
accounts. Findings below were validated with real HTTP requests; severity
follows the triage gate (impact demonstrated, not theoretical).

---

## Verdict

**Conditional Go.** No Critical/High exploitable holes were confirmed in the
backend API surface. The app is in good shape for a student project: ownership
checks are consistently enforced, rate limiting works and is not XFF-spoofable,
JWT alg-confusion is rejected, the maps proxy blocks traversal, and the driver
approval gate (`driver_status`) is enforced on driver endpoints and the tracking
socket. The real risks are **credential hygiene** (plaintext secrets file),
**session/token lifetime on the device**, and a few **hardening gaps** listed
below.

## Confirmed findings

### F1 — Backend secrets live in a plaintext `.env` on disk (High, operational)
- **Where:** `finalyr_project/backend/.env` contains a live Supabase pooler
  password, `CLERK_SECRET_KEY` (`sk_test_...`), `LOCAL_JWT_SECRET`,
  `RAZORPAY_KEY_SECRET`, `STADIA_API_KEY`. It is correctly gitignored (verified:
  not tracked), and CI uses a dummy secret — but the file is one leak away
  (accidental commit, backup, malware) from **full database access + the JWT
  signing key**.
- **Proven impact:** with `LOCAL_JWT_SECRET` I forged a valid token for an
  arbitrary user id and `GET /auth/me` returned the victim's account (200).
  HS256 means the secret *is* the kingdom.
- **Fix:** rotate everything in that file now (Supabase password, Clerk secret,
  Razorpay keys, JWT secret, Stadia key); move to a secrets manager / GitHub
  Actions secrets for deploy; add a pre-commit hook (gitleaks/trufflehog) as a
  safety net.

### F2 — Session token: 7-day non-revocable JWT stored in plaintext SharedPreferences, and Android backup is not disabled (Medium-High, mobile)
- **Where:** `lib/services/api_client.dart` stores the bearer token via
  `SharedPreferences`; `android/app/src/main/AndroidManifest.xml` does not set
  `android:allowBackup="false"` (Android default is `true`); there is no
  `/auth/logout` endpoint, so "logout" is client-side only — the JWT stays valid
  until `exp` (default 7 days, `LOCAL_JWT_EXPIRES_MINUTES=10080`).
- **Proven:** after a simulated logout the same token still returns 200 from
  `/auth/me`. On-device, the token is extractable via `adb backup` (debuggable
  builds) or Android cloud backup.
- **Fix:** `android:allowBackup="false"` (+ `dataExtractionRules`), migrate the
  token to `flutter_secure_storage` (Keystore-backed), add a server-side token
  revocation/denylist or short-lived access tokens, and re-check auth on email
  change (see F3).

### F3 — Email change on `PATCH /auth/me` requires no current password / step-up (Low-Medium)
- `backend/routers/auth.py` `update_current_user` lets any valid session change
  the account email (uniqueness checked, but no re-authentication). Combined
  with F2's long-lived token, a stolen token can silently re-bind the account.
- **Fix:** require current password (or an emailed confirmation) for email
  changes.

### F4 — Any authenticated user can spawn presentation-demo rides and query demand predictions (Low)
- `POST /rides/demo-batch` / `/rides/demo-shared-batch` have no role gate (demo
  rides are created in `PRESENTATION_DEMO_MODE`, scoped to the caller and
  TTL-reclaimed, so blast radius is small — verified). `GET /predict/demand`
  and `/predict/heatmap` return demand data to any passenger (200 verified).
- **Fix:** gate demo endpoints behind admin or `APP_ENV != production`; restrict
  `/predict/*` to admin/driver.

### F5 — No TLS certificate pinning in the app (Low, hardening)
- Release builds use HTTPS (`config.prod.json` → `https://api.fnxdoom.in`) and
  debug cleartext is correctly limited to `10.0.2.2`/`localhost`/`127.0.0.1`
  via `network_security_config` (debug manifest only — verified). But there is
  no certificate pinning, so a user-installed CA or compromised CA can MITM.
- **Fix:** add pinning (e.g. `ssl_pinning`/`cronet` or a `CertificatePinner` in
  the tile HTTP client) for the API host.

## Verified as NOT vulnerable (dynamic tests, all synthetic accounts)

| Test | Result |
|---|---|
| IDOR: attacker reads/cancels/status-changes victim's ride (`/rides/{id}`, `/vehicle`, `/route`, DELETE, PATCH, confirm-pickup) | 403/404 every time |
| IDOR: payments (`/payments/{id}`, create-order for someone else's ride, verify) | 404/400/409, ownership enforced |
| IDOR: notifications read | 404, scoped to owner |
| Unauthenticated access to rides/jobs/analytics/admin with well-formed bodies | 401 everywhere |
| Driver-only endpoints as passenger (dispatch board, vehicle PATCH, location push, route history, optimize, jobs) | 403 |
| Register with `role:"admin"` (mass assignment) | forced to `passenger` |
| JWT `alg=none`, wrong-secret HS256, garbage | 401; only a correctly signed token works |
| Login rate limit | 429 after limit (15/5min), keyed on real client IP, not spoofable XFF; per-user limits on payments |
| Maps proxy path traversal (`../`, `%2f`) | rejected (502 "Invalid Stadia map resource path") |
| WebSocket without/with bad token | 403; passenger token gets scoped snapshot; non-active driver rejected (4403-class fix works) |
| Razorpay webhook with bad signature | 400; verify with garbage → 404; amounts computed server-side; authorized≠captured handled as pending |
| Ride outside India | 422 geofence |
| Login user enumeration | identical 401 for unknown user vs wrong password (registration does reveal existing emails — accepted, low) |
| SQL injection surface | SQLAlchemy ORM / parameterized `text()` with bound params only; no string-built SQL |
| Secrets in the Flutter repo / APK inputs | none found (only doc mentions); `config.prod.json`/`config.local.json` gitignored |
| CORS | `ALLOWED_ORIGINS` from env; prod compose sets explicit origins |
| Rate limiter behind proxy | prod compose runs uvicorn with `--proxy-headers --forwarded-allow-ips=<private ranges>`, so per-IP limits see real client IPs |

## Recommendations (priority order)

1. **Rotate all secrets in `backend/.env` today** and move them out of the repo
   machine (F1).
2. Disable Android backup + move the token to secure storage + add token
   revocation (F2).
3. Require step-up auth for email change (F3).
4. Gate demo/predict endpoints by role or environment (F4).
5. Add TLS pinning for the API host (F5).
6. Keep the existing strengths: ownership checks, real-IP rate limiting,
   driver-status enforcement, webhook signature verification, India geofence.

## Test artifacts

Dynamic tests were run against `http://127.0.0.1:8000` backed by a disposable
`postgis/postgis:16-3.4` container with synthetic accounts only; scripts and
outputs are in the session temp dir (`%TEMP%\opencode\audit*.py`), not committed.
The test DB and server were shut down after the audit.
