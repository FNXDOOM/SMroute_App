# Maps

The basemap is resolved once per session by `lib/services/map_tiles.dart`:

1. **Preferred** — the website's own Stadia basemap, dark variant
   (`alidade_smooth_dark`), fetched through the backend's authenticated proxy:
   `GET /maps/stadia/resource/tiles/alidade_smooth_dark/{z}/{x}/{y}.png` with the
   session bearer token. The API key stays server-side, so no map key is compiled
   into the app. flutter_map fetches tiles from Dart, which means — unlike
   MapLibre's native fetches — it *can* attach the `Authorization` header.
2. **Fallback** — only when the proxy can't serve tiles at all (no token yet,
   offline, or the backend's Stadia key unset): keyless CARTO `dark_all`,
   brightened by a colour matrix because its own road casing is near-black and
   disappears against our canvas.

A single probe tile decides between them (8 s timeout, response must be a real
PNG), so the app never renders a half-broken tile layer.

**Why this matters.** The previous CARTO-only basemap measured *median luma 9*,
with ~80 % of pixels between `#030303` and `#0D0D0D` and roads at
`#111111`–`#222222` — against our own `#000000` canvas. The tiles were loading
perfectly and the map was still effectively invisible. Stadia's dark raster
measures median luma ~52 with roads at `#333333`–`#4F4F4F`, so the map reads as a
map. On-device the map area went from 9 → 56 median luma.

**Known backend issue** — `GET /maps/stadia/resource/...@2x.png` answers **500**
sporadically (13 of roughly 30 tiles in one measured session, each failure a
black hole in the map), while Stadia serves the identical URL with 200 (6/6
repeats). The app therefore requests plain 256 px tiles and retries 5xx twice via
`RetryClient`; a full session after that change logged **zero** tile failures.
Fixing it server-side would restore `@2x` sharpness on high-DPI phones.
