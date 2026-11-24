# Security, reliability, troubleshooting

## Security review

- No secrets, keys or database credentials ship in the app; the bearer token is
  the only stored credential (`shared_preferences` — use
  `flutter_secure_storage` for a hardened production build).
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
