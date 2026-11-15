import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_env.dart';

/// Supplies the CURRENT session token, minting a fresh one when the previous
/// has expired — or null when there is nothing to refresh (backend-native JWT
/// users, or no live Clerk session).
typedef TokenRefresher = Future<String?> Function();

class ApiClient {
  /// Base URL comes from [AppEnv] (build-time config; see lib/config/app_env.dart).
  /// NOTE: `127.0.0.1` reaches the host only from desktop/iOS-simulator.
  /// On the Android emulator use `http://10.0.2.2:8000`; on a physical
  /// device use your production URL or your machine's LAN IP.
  ApiClient._({String? baseUrl, http.Client? httpClient})
      : baseUrl = (baseUrl ?? AppEnv.apiBaseUrl).replaceAll(RegExp(r'/$'), ''),
        _http = httpClient ?? http.Client();

  /// Default timeout for every request so UI loading states can't hang forever.
  static const Duration requestTimeout = Duration(seconds: 15);

  static final ApiClient instance = ApiClient._();

  /// An isolated client over a caller-supplied transport, so token refresh and
  /// 401 recovery can be exercised without a live backend.
  @visibleForTesting
  factory ApiClient.withHttpClient(http.Client httpClient, {String? baseUrl}) =>
      ApiClient._(baseUrl: baseUrl, httpClient: httpClient);

  static const String _tokenKey = 'smartroute_api_token';

  final String baseUrl;

  /// Transport for every request.
  final http.Client _http;
  String? _token;
  bool _initialized = false;

  /// Live-token source installed by [ClerkAuthService]; see [setTokenRefresher].
  TokenRefresher? _tokenRefresher;

  /// The in-progress refresh, so concurrent requests share ONE mint.
  Future<String?>? _refreshInFlight;

  /// Correlation id for the dev-only request log.
  int _requestCounter = 0;

  Future<void> initialize() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
    _initialized = true;
  }

  /// Installs (or clears, with null) the live-token source.
  ///
  /// [ClerkAuthService] installs one, which is what lets every request ask for
  /// the CURRENT session token instead of replaying a snapshot that expired
  /// minutes ago.
  void setTokenRefresher(TokenRefresher? refresher) {
    _tokenRefresher = refresher;
  }

  /// The token as last stored (login, session restore, or last refresh).
  Future<String?> get token async {
    await initialize();
    return _token;
  }

  /// The token the NEXT authenticated request should use.
  ///
  /// Clerk session JWTs live ~60 s, so a token captured at login or app boot is
  /// stale within a minute: replaying that stored snapshot per request is what
  /// produced intermittent "Clerk token has expired" 401s while other requests
  /// kept working. With a [TokenRefresher] installed this returns the current
  /// token (Clerk's own cache makes the common case cheap) and falls back to the
  /// stored token when nothing was refreshed — a failed refresh must never
  /// silently drop authentication.
  Future<String?> liveToken() async {
    await initialize();
    final refreshed = await refreshToken();
    if (refreshed != null && refreshed.isNotEmpty) return refreshed;
    return _token;
  }

  /// Mints a token through the [TokenRefresher], coalescing concurrent callers
  /// into a single mint. Parallel API calls therefore always agree on the token
  /// state instead of racing (some refreshing, some still holding the old one).
  /// Returns null when there is no refresher or nothing could be refreshed.
  Future<String?> refreshToken() {
    final refresher = _tokenRefresher;
    if (refresher == null) return Future<String?>.value();

    final inFlight = _refreshInFlight;
    if (inFlight != null) return inFlight;

    final future = _performRefresh(refresher);
    _refreshInFlight = future;
    unawaited(
      future.whenComplete(() {
        if (identical(_refreshInFlight, future)) _refreshInFlight = null;
      }),
    );
    return future;
  }

  Future<String?> _performRefresh(TokenRefresher refresher) async {
    try {
      final fresh = await refresher();
      if (fresh == null || fresh.isEmpty) return null;
      if (fresh != _token) await setToken(fresh);
      return fresh;
    } on Exception {
      // No session / SDK not ready / network blip — callers fall back to the
      // stored token rather than losing auth.
      return null;
    }
  }

  Future<void> setToken(String? token) async {
    await initialize();
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    if (token == null || token.isEmpty) {
      await prefs.remove(_tokenKey);
    } else {
      await prefs.setString(_tokenKey, token);
    }
  }

  Future<void> clearToken() => setToken(null);

  Uri uri(String path, [Map<String, dynamic>? queryParameters]) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$baseUrl$normalizedPath').replace(
      queryParameters: queryParameters?.map(
        (key, value) => MapEntry(key, '$value'),
      ),
    );
  }

  /// Headers for an already-resolved [token], so a single request attempt never
  /// mints a second token behind the caller's back.
  Map<String, String> _headersFor(String? token) {
    final result = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      result['Authorization'] = 'Bearer $token';
    }
    return result;
  }

  /// Dev-only request logging — the diagnostic trail for the intermittent 401.
  ///
  /// Logs the request id, method, path, status, duration, the token's remaining
  /// lifetime and whether the request was retried. Never logs the token,
  /// the Authorization header, passwords or request bodies.
  void _logRequest(
    String method,
    Uri url,
    Duration elapsed,
    int status, {
    required int id,
    required bool retried,
    int? tokenSecondsRemaining,
  }) {
    if (!kDebugMode) return;
    final ttl = tokenSecondsRemaining == null
        ? 'n/a'
        : '${tokenSecondsRemaining}s';
    // ignore: avoid_print
    print(
      'API  #$id $method ${url.path}  $status  '
      '${elapsed.inMilliseconds}ms  token_ttl=$ttl  retried=$retried',
    );
  }

  /// Seconds until the stored token's `exp` claim (negative once past it), or
  /// null when it can't be read. Decodes ONLY the `exp` claim — token material
  /// is never logged.
  static int? _tokenSecondsRemaining(String? token) {
    if (token == null || token.isEmpty) return null;
    final parts = token.split('.');
    if (parts.length != 3) return null;
    try {
      final payload =
          jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))))
              as Map<String, dynamic>;
      final exp = payload['exp'];
      if (exp is! int) return null;
      return exp - DateTime.now().millisecondsSinceEpoch ~/ 1000;
    } on FormatException {
      return null;
    }
  }

  Future<dynamic> getJson(
    String path, {
    Map<String, dynamic>? queryParameters,
    bool authenticated = true,
  }) => _send(
    'GET',
    path,
    queryParameters: queryParameters,
    authenticated: authenticated,
  );

  Future<dynamic> postJson(
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParameters,
    bool authenticated = true,
  }) => _send(
    'POST',
    path,
    body: body,
    queryParameters: queryParameters,
    authenticated: authenticated,
  );

  Future<dynamic> patchJson(
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParameters,
    bool authenticated = true,
  }) => _send(
    'PATCH',
    path,
    body: body,
    queryParameters: queryParameters,
    authenticated: authenticated,
  );

  Future<dynamic> deleteJson(
    String path, {
    Map<String, dynamic>? queryParameters,
    bool authenticated = true,
  }) => _send(
    'DELETE',
    path,
    queryParameters: queryParameters,
    authenticated: authenticated,
  );

  /// Runs one authenticated request, recovering ONCE from a token that expired
  /// between the mint and the backend's verification.
  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParameters,
    required bool authenticated,
  }) async {
    final url = uri(path, queryParameters);
    final id = ++_requestCounter;
    final sw = Stopwatch()..start();
    try {
      // The token is resolved ONCE per attempt and passed down explicitly, so
      // an attempt can never mint a second token behind our back.
      var token = authenticated ? await liveToken() : null;
      var response = await _dispatch(
        method,
        url,
        token: token,
        body: body,
      );

      var retried = false;
      if (response.statusCode == 401 && authenticated) {
        // A Clerk JWT can expire between `liveToken()` and the backend's
        // verification (60 s lifetime, network latency). Mint a fresh token —
        // single-flight, shared with any other request doing the same — and
        // retry exactly once. If the refresh returned the SAME token, retrying
        // would only repeat the 401, so we don't: that comparison is what keeps
        // this from becoming a 401 → refresh → 401 loop.
        final fresh = await refreshToken();
        if (fresh != null && fresh.isNotEmpty && fresh != token) {
          retried = true;
          token = fresh;
          response = await _dispatch(
            method,
            url,
            token: token,
            body: body,
          );
        }
      }

      sw.stop();
      _logRequest(
        method,
        url,
        sw.elapsed,
        response.statusCode,
        id: id,
        retried: retried,
        tokenSecondsRemaining: _tokenSecondsRemaining(token),
      );
      return _decodeResponse(response);
    } on TimeoutException {
      throw ApiException(0, 'Request timed out. Check your connection.');
    } on http.ClientException {
      // Socket/DNS failures arrive as ClientException (the socket variant also
      // implements SocketException) — map them so isNetworkFailure sees them.
      throw ApiException(0, 'Could not reach the server. Check your connection.');
    }
  }

  Future<http.Response> _dispatch(
    String method,
    Uri url, {
    required String? token,
    Map<String, dynamic>? body,
  }) async {
    final requestHeaders = _headersFor(token);
    final encoded = body == null ? null : jsonEncode(body);
    return await (switch (method) {
      'GET' => _http.get(url, headers: requestHeaders),
      'POST' => _http.post(url, headers: requestHeaders, body: encoded),
      'PATCH' => _http.patch(url, headers: requestHeaders, body: encoded),
      'DELETE' => _http.delete(url, headers: requestHeaders),
      _ => throw ArgumentError.value(method, 'method'),
    }).timeout(requestTimeout);
  }

  dynamic _decodeResponse(http.Response response) {
    dynamic body;
    if (response.body.isNotEmpty) {
      try {
        body = jsonDecode(response.body);
      } on FormatException {
        // Non-JSON error page (e.g. proxy 502 HTML) — preserve status + snippet.
        final snippet = response.body.length > 200
            ? '${response.body.substring(0, 200)}…'
            : response.body;
        throw ApiException(
          response.statusCode,
          'Request failed with status ${response.statusCode}: $snippet',
        );
      }
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    final message = switch (body) {
      Map<String, dynamic> data when data['detail'] != null =>
        data['detail'].toString(),
      Map<String, dynamic> data when data['message'] != null =>
        data['message'].toString(),
      _ => body?.toString() ?? 'Request failed with status ${response.statusCode}',
    };
    throw ApiException(response.statusCode, message,
        retryAfterSeconds: _parseRetryAfter(response));
  }

  /// Parses the backend's `Retry-After` header (seconds) on 429 responses.
  /// The backend's RateLimitBodyGuardMiddleware always sends it on 429.
  static int? _parseRetryAfter(http.Response response) {
    if (response.statusCode != 429) return null;
    final raw = response.headers['retry-after'];
    if (raw == null) return null;
    return int.tryParse(raw.trim());
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;

  /// Seconds to wait before retrying, from the backend's `Retry-After`
  /// header. Only set on 429 responses. Callers SHOULD honour it instead of
  /// retrying immediately (which would just hit the limit again).
  final int? retryAfterSeconds;

  ApiException(this.statusCode, this.message, {this.retryAfterSeconds});

  /// True when the backend rejected the credentials / token.
  bool get isUnauthorized => statusCode == 401 || statusCode == 403;

  /// True when the request never reached the backend (timeout / offline /
  /// DNS). Callers should NOT treat this as "logged out".
  bool get isNetworkFailure => statusCode == 0;

  /// True when the backend rate-limited this request.
  bool get isRateLimited => statusCode == 429;

  /// True when the backend rejected the payload (validation, or outside the
  /// India service area).
  bool get isValidationError => statusCode == 400 || statusCode == 422;

  @override
  String toString() => 'ApiException($statusCode, $message)';
}
