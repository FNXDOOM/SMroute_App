import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/retry.dart';

import 'api_client.dart';

/// A raster basemap the map can render.
///
/// The website's basemap is only reachable through the backend's authenticated
/// tile proxy, so a map that draws Stadia tiles must send the session bearer
/// token with every tile fetch. That token is supplied per request by
/// [SessionTokenClient] rather than by [headers]: a tile layer outlives a Clerk
/// JWT by orders of magnitude, so a token baked in here would 401 the moment it
/// expired and leave the map black while the rest of the app kept working.
@immutable
class MapTileSource {
  const MapTileSource({
    required this.id,
    required this.label,
    required this.urlTemplate,
    required this.attributions,
    this.headers = const <String, String>{},
    this.subdomains = const <String>[],
    this.brighten = false,
    this.retina = true,
    this.retryOnServerError = false,
    this.usesSessionToken = false,
  });

  final String id;
  final String label;
  final String urlTemplate;
  final List<String> attributions;

  /// Static headers for this basemap. The authenticated proxy leaves these
  /// empty and relies on [usesSessionToken] instead.
  final Map<String, String> headers;
  final List<String> subdomains;

  /// True for the keyless fallback, whose road casing is a near-black
  /// `#111111`–`#222222` on a `#030303` base — invisible against our own black
  /// canvas. [LiveMap] lifts it with a colour matrix so the roads read at
  /// roughly the site's `#545454` instead of vanishing.
  final bool brighten;

  /// Whether to request 2× tiles. Only safe where the tile host serves `{r}`.
  final bool retina;

  /// Retry 5xx responses. The backend's tile proxy intermittently 500s, and
  /// an unrecovered failure shows up as a black hole in the map.
  final bool retryOnServerError;

  /// Whether tile requests must carry the current `Authorization: Bearer`
  /// session token (the backend's Stadia proxy). Resolved live per request.
  final bool usesSessionToken;
}

/// An [http.Client] that stamps the CURRENT session token on every tile request.
///
/// The tile provider holds this client for the lifetime of the map, so the
/// token must be read per request — see [ApiClient.liveToken].
class SessionTokenClient extends http.BaseClient {
  SessionTokenClient(this._inner, this._api);

  final http.Client _inner;
  final ApiClient _api;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final token = await _api.liveToken();
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}

/// Picks the basemap for [LiveMap], preferring the website's own Stadia tiles
/// proxied through the backend so both clients draw the same map.
///
/// The website loads a MapLibre *vector* style
/// (`GET /maps/stadia/style.json`) and then repaints it dark in the browser.
/// flutter_map only renders raster tiles, so the app asks the backend's
/// resource proxy (`/maps/stadia/resource/...`, the same proxy the website's
/// sprites and glyphs come from) for Stadia's raster sibling of that style,
/// `alidade_smooth_dark`. The API key stays server-side — the app never sees
/// it, and no map key ships in the binary.
class MapTiles {
  MapTiles._();

  /// The website's basemap family, dark variant.
  ///
  /// Plain 256px tiles, deliberately without `{r}`: the backend proxy returns
  /// intermittent 500s for `@2x` tiles (Stadia itself serves them fine), and a
  /// missing tile renders as a black hole on our canvas. The plain endpoint is
  /// what the probe — and therefore the fallback decision — is based on.
  static const String stadiaTemplate = '{base}/maps/stadia/resource/'
      'tiles/alidade_smooth_dark/{z}/{x}/{y}.png';

  /// Keyless fallback used only when the proxy can't serve tiles (offline, a
  /// token that has expired, or the backend's Stadia key being unset). CARTO's
  /// dark basemap is far too dark on its own, so it renders brightened.
  static const String fallbackTemplate =
      'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png';

  /// One known-good tile inside the service area, used to prove the proxy can
  /// actually deliver tiles before we commit to it.
  static const String _probePath =
      '/maps/stadia/resource/tiles/alidade_smooth_dark/13/5861/3798.png';

  static const String _stadiaAttribution =
      '© Stadia Maps © OpenMapTiles © OpenStreetMap contributors';

  static const Duration probeTimeout = Duration(seconds: 8);

  static MapTileSource? _cached;
  static String? _cachedBase;
  static Future<MapTileSource>? _inFlight;

  /// Result of the last probe — exposed for the README's troubleshooting steps
  /// and for tests.
  static String? lastProbeNote;

  static MapTileSource get fallback => const MapTileSource(
        id: 'carto-dark',
        label: 'Dark raster (keyless fallback)',
        urlTemplate: fallbackTemplate,
        subdomains: <String>['a', 'b', 'c', 'd'],
        attributions: <String>['© OpenStreetMap contributors', '© CARTO'],
        brighten: true,
      );

  /// The HTTP client a tile layer should use for [source]: live session-token
  /// auth for the backend's proxy, 5xx retries where the proxy needs them, or
  /// null to let flutter_map use its own default.
  static http.Client? tileHttpClient(MapTileSource source) {
    if (!source.usesSessionToken && !source.retryOnServerError) return null;
    http.Client client = http.Client();
    if (source.usesSessionToken) {
      client = SessionTokenClient(client, ApiClient.instance);
    }
    if (source.retryOnServerError) {
      client = RetryClient(
        client,
        retries: 2,
        when: (response) => response.statusCode >= 500,
      );
    }
    return client;
  }

  /// Resolves the basemap once per session (and again after a login/logout,
  /// since the token is what unlocks the good one).
  static Future<MapTileSource> resolve({ApiClient? client}) {
    final api = client ?? ApiClient.instance;
    return _inFlight ??= _resolve(api).whenComplete(() => _inFlight = null);
  }

  static Future<MapTileSource> _resolve(ApiClient api) async {
    final token = await api.liveToken();

    if (token == null || token.isEmpty) {
      lastProbeNote = 'No session token yet — using the keyless fallback.';
      return fallback;
    }
    final base = api.baseUrl.replaceAll(RegExp(r'/$'), '');
    // Keyed to the origin, not the token: Clerk JWTs rotate ~60 s and the
    // exact-token key re-ran the 8 s probe on almost every map open. Logout
    // clears the cache via reset(), so a signed-out session re-resolves.
    if (_cached != null && _cachedBase == base) return _cached!;

    if (await _proxyServesTiles(base)) {
      lastProbeNote = 'Backend tile proxy OK — using the website\'s basemap.';
      final source = MapTileSource(
        id: 'stadia-dark',
        label: 'Stadia alidade_smooth_dark (via backend proxy)',
        urlTemplate: stadiaTemplate.replaceFirst('{base}', base),
        attributions: const <String>[_stadiaAttribution],
        retina: false,
        retryOnServerError: true,
        // Token comes from the client, per request — never from a header
        // captured here, which would expire mid-session.
        usesSessionToken: true,
      );
      _cached = source;
      _cachedBase = base;
      return source;
    }

    lastProbeNote = 'Tile proxy unavailable — using the keyless fallback.';
    // Not cached: a later login or a recovered backend should upgrade us.
    return fallback;
  }

  /// Asks the backend for a single real tile. A 200 with a plausible PNG body
  /// means the proxy, the stored Stadia key and the token are all working.
  static Future<bool> _proxyServesTiles(String base) async {
    final client = SessionTokenClient(http.Client(), ApiClient.instance);
    try {
      final request = http.Request('GET', Uri.parse('$base$_probePath'))
        ..headers['Accept'] = 'image/png,image/*';
      final streamed = await client.send(request).timeout(probeTimeout);
      if (streamed.statusCode != 200) return false;
      final bytes = await streamed.stream.toBytes();
      // PNG magic, so a JSON error page can't pass as a tile.
      return bytes.length > 128 && bytes[0] == 0x89 && bytes[1] == 0x50;
    } on Exception {
      return false;
    } finally {
      client.close();
    }
  }

  /// Clears the cache (logout, or a token refresh).
  static void reset() {
    _cached = null;
    _cachedBase = null;
  }
}
