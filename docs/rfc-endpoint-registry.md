# RFC: Endpoint registry — one owner for the backend contract

Status: proposed
Design: typed `Endpoint<T>` catalog (option B) behind a two-method execution
surface (option A), verified against OpenAPI fixtures (option D's detector,
without D's port).
Supersedes nothing. Follows the client/backend drift review that recovered the
uncommitted carpool work (`6c5986e`) and deleted the phantom rating call
(`7388b78`).

## Problem

The client knows the backend's HTTP surface as **37 string literals smeared
across 8 files** — `ride_provider.dart`, `driver_service.dart`,
`carpool_service.dart`, `geocoding_service.dart`, `location_service.dart`,
`routing_service.dart`, `razorpay_service.dart`, `notification_provider.dart` —
each interpolating paths at the call site. The module is shallow: what a caller
must know (method, path, slash form, where each parameter goes, which envelope
wraps the answer) is almost the whole implementation.

Three consequences, all observed rather than theoretical:

1. **A fictional endpoint lived in production unnoticed.** The app posted to
   `POST /rides/{id}/rating`, which the backend has never implemented — no model,
   no column, no schema. The 404 was caught and discarded, and the UI thanked the
   rider. Nothing in the type system or the test suite could object, because
   "call this endpoint" and "type a string" are the same act. Fixed by deletion
   in `7388b78`, but the shape of the failure remains available to any future route.
2. **Drift is detected by hand.** The backend is 18 commits newer than the client
   (`7618bab` made 11 driver endpoints require `driver_status == 'active'`;
   `e8b2497` added the per-rider carpool axis; `49ea6e4` deleted schemas). Finding
   that out required diffing two repos and reading response models one at a time.
   The backend's own suite calls most route functions directly rather than over
   HTTP, so `/auth/login`, `/rides/request`, `/geocode/*`, `/analytics/*` and
   `/jobs/*` have no wire-shape coverage on either side.
3. **Per-route facts get re-derived at every call site**, inconsistently:
   envelope unwrapping is hedged where a caller guessed wrong, and `ApiException`
   already parses `Retry-After` into `retryAfterSeconds` which no caller reads —
   so a throttled booking is reported as a generic failure.

Adding the ~36 currently unreachable routes under this shape costs one careful
edit per route per file, with no compile-time or test-time protection.

## Proposed interface

Four public names. Two methods a caller executes.

```dart
/// Who the backend lets through. `activeDriver` is the 7618bab rule:
/// driver_status == 'active', which is NOT the same as role == 'driver'.
enum Guard { public_, anyUser, activeDriver, staff }

/// One route, fully described. Private constructor: only a catalog can build
/// one, so an Endpoint can never be assembled from a hand-typed string.
final class Endpoint<T> {
  const Endpoint._(/* ... */);

  final Verb verb;                    // get|post|patch|delete — no put exists
  final String template;              // '/rides/' — slashes literal, never normalized
  final Map<String, Object?> pathArgs, query;
  final Map<String, Object>? body;
  final Guard guard;
  final String rateGroup;             // backend rate limits are per prefix
  final T Function(Object response) decode;  // envelope unwrap + model parse
}

/// Catalogs, one file per backend router. The only place a path may appear.
abstract final class Rides {
  static Endpoint<RideRecord> request(RideDraft d) => Endpoint._(
        verb: Verb.post, template: '/rides/request', body: d.wire,
        guard: Guard.anyUser, rateGroup: 'rides',
        decode: (r) => RideRecord.fromJson(_asMap(r)),
      );

  static final dispatchBoard = Endpoint<List<RideRequestRecord>>._(
    verb: Verb.get, template: '/rides/',        // the slash is the route
    query: {'limit': 50}, guard: Guard.activeDriver, rateGroup: 'rides',
    decode: (r) => _asList(r).map(RideRequestRecord.fromJson).toList(),
  );
}

extension ApiExecution on ApiClient {
  /// The one way to reach the backend.
  Future<T> call<T>(Endpoint<T> endpoint);
  /// ws(s) scheme rewrite + a freshly minted token as ?token= , per attempt.
  Future<Uri> socket(Endpoint<Never> endpoint);
}
```

Callers:

```dart
// passenger books
final ride = await _api.call(Rides.request(draft));

// driver board — guard is data, so the UI can pre-check without a round trip
if (!Rides.dispatchBoard.usableFor(session)) return;
final board = await _api.call(Rides.dispatchBoard);

// tracking socket — no baseUrl poking, no token in caller code
final uri = await _api.socket(Tracking.socket);
```

### What it hides

| Backend fact | Where it stops leaking |
|---|---|
| Trailing slashes are semantic; a 307 on POST drops the body | templates are literal; `call` asserts a non-GET response is never 3xx, catching the catalog's own typos |
| Query vs body vs path placement (`?role=` on the admin route, `/jobs/run/*` query-only with empty body, `/rides/demo-batch` all-query) | `pathArgs`/`query`/`body` on the entry; a call site cannot relocate a parameter |
| `lat`/`lng` here, `latitude`/`longitude` on `/predict/*` | bound per route from one coordinate value |
| `Guard.activeDriver`, passenger 403 on `/tracking/feed` | `guard` + `usableFor`, advisory only |
| Bare arrays vs `{status, vehicles}` vs `{status, runs}` vs `{status, updated_count}` (a count in an action model) | `decode`, so no provider casts `response['rides']` |
| Valhalla camelCase passthrough vs persisted snake_case; `[lng,lat]` vs scalar `stops[].lat/lng` | codecs inside the catalog entry that owns the route |
| `detail` as string / 422 list / `missing_vehicle_ids` object | one `ApiException` |
| Per-prefix 429 + `Retry-After` | `rateGroup`; `call` honours the existing, unread `retryAfterSeconds` |

## Dependency strategy

Category 3 — *remote but owned*. The port is the **transport**, not the routes:
today's `ApiClient` internals (live token per request, single-flight refresh,
retry-once-without-looping on 401, 15s timeout, the GET/POST/PATCH/DELETE-only
dispatch) stay exactly where they are and become the production adapter. The
in-memory adapter is the `MockClient` the suite already injects.

Deliberately **not** a `BackendApi` port with one method per route. That
re-exposes all 37 routes in the interface, which is the shallowness being
removed; its genuinely valuable half — fixture-derived contract checking — is
adopted below and does not need the port.

## Testing strategy

Replace, don't layer.

**Delete once boundary tests exist:**
- the 8 `METHOD /path` string assertions in `test/carpool_service_test.dart` —
  they duplicate the catalog and must be edited whenever a route is renamed;
  `registry_golden_test` covers those routes and 29 more.
- the payload-shape cases in `test/backend_contract_test.dart` that hand-write
  `PaymentResponse`/`RideRequestResponse`/`VehicleSnapshot`/`NotificationListResponse`
  JSON, once the same models are driven from fixtures.

**Keep:** the token-refresh and 401-recovery group. They exercise the transport
port and are unaffected by the catalog.

**New tests at the interface boundary:**
1. `registry_golden_test` — for every entry, resolve against a dummy base URL and
   assert the rendered `METHOD /path?query` against a checked-in table. One row
   per route; a rename edits one line, and the 8 deleted string asserts live here.
2. `openapi_contract_test` — load `test/fixtures/openapi.json` and assert for each
   entry: the `(method, path)` pair exists; the slash form matches exactly;
   parameters the catalog puts in `query` appear under `parameters`, and those in
   `body` appear under `requestBody`; response property names are a superset of
   what that entry's decoder reads. **This is the drift detector: a backend
   change becomes one failing Dart test instead of a manual two-repo diff.**
3. `call` never sends a body on a route declared query-only, and never emits PUT.
4. Envelope handling: a `{status, updated_count}` route yields an `int`; a bare
   array yields a `List`; an HTTP 200 carrying `{status: 'error'}` throws.
5. `Retry-After` on 429 is honoured by `call`'s backoff, closing the unread field.
6. `Guard` is advisory: `usableFor` false prevents the call, and a real 403 still
   maps to the same `ApiException` the transport produces today.

**Test environment:** one addition — `tool/dump_openapi.py` in the backend repo
writes `openapi.json` plus one response fixture per `operationId`, regenerated by
CI. FastAPI already serves this without running any route, so the backend's
missing HTTP tests are not a blocker.

## Implementation recommendations

Durable guidance, not coupled to today's file names.

- **Owns:** the full description of every route the client can reach — verb, path
  form, parameter placement, authorization, rate group, response envelope, decoder.
- **Hides:** base-URL handling, ws scheme rewrite, token attachment, envelope
  unwrapping, casing and coordinate-order conventions, error normalization, and
  backoff. No caller should ever see a JSON map.
- **Exposes:** `Endpoint<T>`, `Guard`, the per-router catalogs, and two execution
  methods. Anything wider is a regression of the thing being fixed.
- **Migration,** each step independently shippable, ordered by call frequency:
  1. catalog + `call`/`socket` + golden test. No call sites move.
  2. carpool's 8 routes — its test loses 8 string asserts and gains nothing at
     the call site, proving the seam works before anything risky.
  3. the three hot pollers (ride status, assigned vehicle, dispatch board) and
     both socket URLs, which also removes the duplicated ws-block.
  4. geocoding / routing / location, then payments and notifications.
  5. `ride_provider` verb groups, a few at a time.
  6. `@Deprecated` the four verb methods; make an unknown path a test failure.
- **Guards that keep it deep:** a lint or CI grep failing any path literal outside
  the catalog directory; every catalog entry must have at least one caller or be
  explicitly tagged as forward-declared, so the 36 unwired routes do not read as
  dead code.
- **Non-goals:** authorization (only the backend knows `driver_status`; treat
  `usableFor` as a UX hint, never a security check), caching, retry-policy
  redesign, and the ride/carpool state machine — the duplicated status ladder
  across 10 files is a separate deepening candidate.

## Rejected alternatives

- **A 21-entry-point domain facade** (`Api.instance.rides.board()`). Kind to the
  hot tier, but a third of its surface is the tail re-typed as methods, and two
  spellings of one call invites drift.
- **A 28-method `BackendApi` port with a hand-written fake.** Best end-to-end
  offline testability on offer, and the most maintenance: three edits per route,
  a fake that can lie, and an interface as wide as the route list. Its OpenAPI
  fixture idea is adopted here precisely because it does not require the port.
