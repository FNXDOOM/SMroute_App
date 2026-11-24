# Screens and flows

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
| `/driver` | Driver console (role-gated) | Vehicle + duty + GPS push, dispatch board, and the assigned pooled route drawn leg by leg with the next stop called out |

**Primary journey** — book, watch, complete:

```text
Home (pickup + destination + tier)  →  POST /rides/request
   → sheet switches to the active-ride panel (6-stage stepper, driver/vehicle)
   → Track live                          →  GET /rides/{id} · /rides/{id}/vehicle
   → vehicle appears                     →  /tracking/ws updates its position
   → status = completed                  →  receipt + fare payment
```

## Feature status

**Live (real backend + database)**

- Auth: register, login, session restore, logout — local JWT, with a Clerk
  email-code path for accounts created on the website (see
  [backend contract](./backend-contract.md#authentication)).
- Booking: GPS pickup, tap-to-pick pickup/destination, debounced place
  autocomplete, live-traffic routing and ETA, ride request, ride cancel.
- Tracking: ride status polling, assigned-vehicle polling, live vehicle
  position over `/tracking/ws` (snapped onto the road polyline — see
  [live ride animation](./live-ride-animation.md)), follow-camera during
  `in_progress`.
- Trips and trip detail, notifications (incl. realtime push), payment history,
  profile updates.

**Static by design (no backend counterpart)**

- Ride-tier names, descriptions, ETAs and price ranges come from
  `lib/models/mock_data.dart`. The backend exposes no pricing/quote endpoint.
  Option **IDs must match** the backend's `RIDE_FARES` table
  (`backend/services/razorpay_service.py`) because payment amounts are computed
  server-side from them — the client can never invent a price.

**Not implemented (honest gaps)**

- **Post-ride feedback** — the backend has no rating model, route or column, so
  the app no longer collects ratings. A previous screen posted to
  `POST /rides/{id}/rating`, swallowed the resulting 404 and thanked the rider
  for feedback that was then discarded; it has been removed rather than left to
  pretend. Reinstating it needs the endpoint first.
- **Admin portal** — the website's role-gated `AdminView` (driver verification,
  jobs, analytics, demand heatmap) has no app equivalent.
- **Vector map styling** — the website renders MapLibre from
  `GET /maps/stadia/style.json` and repaints that vector style dark in the
  browser. `flutter_map` renders raster only, so the app requests Stadia's
  raster sibling of the same style through the backend proxy (see
  [maps](./maps.md)). Same basemap, but the app can't reproduce the site's
  per-layer vector paint rules (e.g. its custom road colour) — it gets the
  pre-rendered dark raster instead.

**Site parity**

- **Razorpay checkout** — the active-ride sheet carries the website's
  `RazorpayPayment` flow: `POST /payments/create-order` → native Razorpay
  Checkout → `POST /payments/verify`. See
  [backend contract](./backend-contract.md#payment-trust-boundary).
- **Driver apply** — `POST /auth/driver/apply` with license plate (the site's
  DriverApplyView), reachable from Profile for passengers.
- **Driver console** (`/driver`, role-gated) — the site's DriverView on
  mobile: vehicle auto-selection by `driver_user_id` (with picker fallback),
  on/off duty via `PATCH /vehicle/{id}`, GPS position push via
  `POST /tracking/vehicles/{id}/location`, dispatch board via `GET /rides/`,
  and accept → arriving → in_progress → completed via `PATCH /rides/{id}/status`
  (completing returns the vehicle to idle, like the site). The console also draws
  the vehicle's **assigned pooled route** with the next stop called out,
  refreshed on the same 6 s board poll.
- **Pooled (shared) ride** — when the backend pools a ride into an optimized
  route, `GET /rides/{id}/route` gives the app the whole route: every stop in
  visit order, the drive split per leg, and which legs are the rider's own. A chip
  on the map switches between the rider's own pickup → drop-off line and the
  pooled route's legs (offered only when there is more than one leg), with
  numbered stop pins and the rider's own leg in the accent colour.
  `problem: "pdp"` means the route pools pickups *and* drop-offs; the older
  `cvrp` fallback returns to the hub and has no per-rider drop-off.
- **Driver's pooled route** — the console's route panel is fed by
  `GET /route/history/{id}` (the route id sits on the vehicle row), mapped through
  the same model the passenger view uses, so one map and one toggle serve both.
  The driver's plan additionally names the rides at each stop, which is what makes
  the **next stop to serve** callout possible: the first stop whose rides are not
  yet terminal, with the straight-line distance from the vehicle's last pushed
  position and an ETA from the route's own average speed. Completing a ride
  advances the callout on the next poll. The passenger view keeps other riders
  private and so never shows it.

**Deliberately absent** — no mock fallbacks anywhere: a failing backend produces
an error or empty state, never fabricated data. Wallet balances, stored cards
and a "scheduled rides" list were removed because the backend has no such
endpoints and the website has no such features.
