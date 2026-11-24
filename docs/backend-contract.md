# Backend contract

How the app talks to the existing FastAPI backend. The backend is the source of
truth for business rules; this client re-implements none of them.

```text
Auth:            Authorization: Bearer <jwt>, Content-Type: application/json
Error format:    {"detail": "<message>"} (FastAPI); 429 adds Retry-After
Token:           local JWT (default 7 days, no refresh — re-login on expiry)
                 or Clerk session JWT (~60 s — resolved live before every
                 request, plus one refresh + retry if the backend reports one
                 expired mid-flight)
WebSocket auth:  ?token=<jwt> query param (backend's native-mobile fallback)
Pagination:      notifications limit=1..100; rides/payments capped server-side
Rate limits:     /auth/login 15/5min · /auth/register 5/h · /rides/request 20/min
                 /geocode 60/min · /payments/create-order 10/10min
```

## Endpoint map

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
| Pooled route (rider) | `/rides/{id}/route` | GET | Yes | – | `RideRouteResponse` or `null` (stops, per-leg geometry, `my_leg_indices`) | Home, tracking |
| Pooled route (driver) | `/route/history/{id}` | GET | Yes (admin/driver) | – | Route plan: `waypoints[]` with `passenger_ids`, `geometry`, `legs[]`, `problem` | Driver console |
| Live tracking | `/tracking/ws?token=` | WS | Yes | – | `{type:"tracking_snapshot"\|"vehicle_location_update",...}` | Tracking |
| Notifications | `/notifications/?limit=100` | GET | Yes | – | `{status,unread_count,notifications[]}` | Inbox, badge |
| Mark all read | `/notifications/read-all` | PATCH | Yes | – | `{status,updated_count}` | Inbox |
| Mark one read | `/notifications/{id}/read` | PATCH | Yes | – | `{status,notification}` | Inbox |
| Notification push | `/notifications/ws?token=` | WS | Yes | – | `{type:"notification",notification:{...}}` | Inbox, ride stages |
| Payment history | `/payments/mine` | GET | Yes | – | `[PaymentResponse]` | Payment |
| Reverse geocode | `/geocode/reverse?lat=&lng=` | GET | Yes | – | `{lat,lng,label}` (India-only) | Map picker / GPS |
| Snap to road | `/routing/nearest-road?lat=&lng=` | GET | Yes | – | `{lat,lng}` | Map picker |
| Road route | `/routing/route?from_lat&from_lng&to_lat&to_lng&traffic` | GET | Yes | – | `{distanceMeters,durationSeconds,geometry:[[lng,lat]]}` | Home, tracking |
| Map style (site) | `/maps/stadia/style.json` | GET | Yes | – | MapLibre style JSON | Not used (see [maps](./maps.md)) |

The backend is **India-guarded**: every ride write and geocode lookup outside
the India bounding box is rejected (422). The client mirrors that check for a
clear message but the server stays authoritative.

## Authentication

```text
Register / Login → POST /auth/register | /auth/login → {access_token, user}
   → token in SharedPreferences (smartroute_api_token)
   → Authorization: Bearer <jwt> on every request (ApiClient.liveToken)

Website account (its password lives in Clerk, not in the backend DB)
   → POST /auth/login returns 401 by design
   → clerk_flutter attemptSignIn(emailCode, identifier) emails a 6-digit code
   → user enters the code → attemptSignIn(emailCode, code) verifies it
   → ClerkAuthState.sessionToken().jwt (fresh, short-lived)
   → same ApiClient storage; backend verifies it via Clerk JWKS (RS256)
   → get_or_create_user_from_payload provisions/links the database user

Token resolution (Clerk sessions only)
   → every request asks ApiClient.liveToken() for the CURRENT token
     (ClerkAuthState.sessionToken(), installed via setTokenRefresher);
     concurrent refreshes are coalesced into a single mint
   → 401 → refresh once → retry the request once. Never loops: if the
     refresh returns the SAME token the request is not retried
   → backend-native JWTs have no refresher, so a 401 stays a re-login

App restart → same path, then GET /auth/me
   → 200: restored · 401/403: token cleared → Login
   → network/5xx: session kept and retried next launch (no forced logout)

Logout → ClerkAuthService.signOut() (Clerk sessions) + token cleared
        + per-account provider state cleared (rides, notifications, payments)
```

This Clerk instance has **password sign-in disabled** — email one-time-code is
its only first factor — which is why the app mirrors the website's code flow
instead of attempting passwords. Accounts created *inside the app* keep using
the fast local-JWT path and never touch Clerk.

## Payment trust boundary

The Razorpay flow on the active-ride sheet is the website's `RazorpayPayment`:
`POST /payments/create-order` → native Razorpay Checkout (`razorpay_flutter`)
→ `POST /payments/verify`. Success is shown **only** after the backend confirms
the signature. A provider state of `authorized` (not yet `captured`) is
reported by the backend as `status: "pending"` — the app treats it as
"check payment status" and reconciles through `GET /payments/mine` rather
than reopening checkout. The Key Secret never reaches the app; all amounts are
computed server-side from the ride option id.

## Tracking socket revocation

The server re-checks authorization on every tracking message and closes the
socket with **code 4403** ("Tracking access revoked") when the account's role
or `driver_status` no longer qualifies (e.g. a driver deactivated mid-ride).
The app treats 4403 as terminal for that socket — reconnecting with the same
identity would just be refused again — and falls back to the REST position
poll (`GET /rides/{id}/vehicle`) so the map keeps updating.
