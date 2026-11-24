# Live ride animation

The map's moving car is **derived from the ride status**, not from driver
telemetry. That is not a shortcut — it is what the website does, and it is
forced by the backend:

- `run_simulate_ride_dispatch_job` (`backend/services/background_jobs.py`)
  advances `assigned → arriving → in_progress → completed` on a **5 s timer**
  and never writes `Vehicle.lat/lng`, so there is no driver movement to consume.
- An admin/driver `PATCH /rides/{id}/status` **nulls `ride.virtual_stop_id`**,
  after which `GET /rides/{id}/vehicle` returns `null` for the rest of the ride.

So `lib/services/ride_vehicle_animation.dart` projects the status onto a path,
exactly like `PassengerView.jsx`'s `simDriver`:

| Status | Path | Duration |
|---|---|---|
| `pending`, `clustered` | none (no driver yet) | — |
| `assigned` | pickup + (0.012, 0.0072) → pickup | 25 s |
| `arriving` | pickup + (0.004, 0.0024) → pickup | 12 s |
| `in_progress` | `RouteEstimate.geometry`, else a straight pickup → destination | 18 s |
| `completed`, `cancelled` | none — the car settles and stops | — |

A real fix (`/tracking/ws`, or the 4 s `GET /rides/{id}/vehicle` poll) always
**beats** the synthetic start; the car is only fabricated when the backend has
nothing to offer.

## Route projection (live fixes)

Real fixes are snapped onto the road polyline before drawing, ported from the
website's `routeUtils.buildRoute` / `passengerMotion.js`:

- `lib/services/route_trace.dart` indexes the route polyline by cumulative
  distance and projects a raw GPS fix onto its nearest point on the road.
- `lib/widgets/live_map.dart` draws the projected point whenever the fix lands
  within **65 m** of the polyline, so the car glides along the street instead of
  drifting with GPS noise. Farther fixes are drawn raw — a real detour must
  never be snapped onto a stale route.
- `lib/services/passenger_motion.dart` holds the fix-acceptance guards: a fix
  that would move the marker backwards, or jump it more than **200 m** in one
  step, is rejected rather than drawn; heading turns ease instead of snapping.

## Motion mechanics

`lib/widgets/live_map.dart` walks the animation. One `Ticker` drives two
mechanisms, ported from `AppMap.jsx`: a **path walk** (`samplePath` —
distance-weighted, `cos(lat)` corrected, heading from the segment) and a
**1200 ms smoothstep retarget** for discrete position updates. The invariant
that makes it feel continuous: each vehicle's motion holds the position it is
*drawn* at, so a new GPS fix, a status change or a route arriving late all
continue from there. `retargetPath()` keeps a same-goal transition
(assigned → arriving) from reversing to the new synthetic offset. Only the
vehicle `MarkerLayer` repaints per frame, and the ticker stops when everything
settles.

**Deliberate divergence from the website:** the site loops its animation
(`loop: true`), so the car drives to the pickup and starts over. Ride tracking
here is non-looping — the car settles at the pickup, follows the road route to
the drop-off, and stops there.
