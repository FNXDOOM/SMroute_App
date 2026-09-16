import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_env.dart';

class ApiClient {
  /// Base URL comes from [AppEnv] (build-time config; see lib/config/app_env.dart).
  /// NOTE: `127.0.0.1` reaches the host only from desktop/iOS-simulator.
  /// On the Android emulator use `http://10.0.2.2:8000`; on a physical
  /// device use your production URL or your machine's LAN IP.
  ApiClient._({String? baseUrl})
      : baseUrl = (baseUrl ?? AppEnv.apiBaseUrl).replaceAll(RegExp(r'/$'), '');

  /// Default timeout for every request so UI loading states can't hang forever.
  static const Duration requestTimeout = Duration(seconds: 15);

  static final ApiClient instance = ApiClient._();

  static const String _tokenKey = 'smartroute_api_token';

  final String baseUrl;
  String? _token;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
    _initialized = true;
  }

  Future<String?> get token async {
    await initialize();
    return _token;
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

  Future<Map<String, String>> headers({bool authenticated = true}) async {
    await initialize();
    final result = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (authenticated && _token != null && _token!.isNotEmpty) {
      result['Authorization'] = 'Bearer $_token';
    }
    return result;
  }

  /// Dev-only request logging. Never logs tokens, passwords or request
  /// bodies — only method, path and duration (see README.md §Security review).
  void _logRequest(String method, Uri url, Duration elapsed, int status) {
    if (!kDebugMode) return;
    // ignore: avoid_print
    print('API  $method ${url.path}  $status  ${elapsed.inMilliseconds}ms');
  }

  Future<dynamic> getJson(
    String path, {
    Map<String, dynamic>? queryParameters,
    bool authenticated = true,
  }) async {
    try {
      final url = uri(path, queryParameters);
      final sw = Stopwatch()..start();
      final response = await http
          .get(url, headers: await headers(authenticated: authenticated))
          .timeout(requestTimeout);
      sw.stop();
      _logRequest('GET', url, sw.elapsed, response.statusCode);
      return _decodeResponse(response);
    } on TimeoutException {
      throw ApiException(0, 'Request timed out. Check your connection.');
    }
  }

  Future<dynamic> postJson(
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParameters,
    bool authenticated = true,
  }) async {
    try {
      final url = uri(path, queryParameters);
      final sw = Stopwatch()..start();
      final response = await http
          .post(
            url,
            headers: await headers(authenticated: authenticated),
            body: body == null ? null : jsonEncode(body),
          )
          .timeout(requestTimeout);
      sw.stop();
      _logRequest('POST', url, sw.elapsed, response.statusCode);
      return _decodeResponse(response);
    } on TimeoutException {
      throw ApiException(0, 'Request timed out. Check your connection.');
    }
  }

  Future<dynamic> patchJson(
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParameters,
    bool authenticated = true,
  }) async {
    try {
      final url = uri(path, queryParameters);
      final sw = Stopwatch()..start();
      final response = await http
          .patch(
            url,
            headers: await headers(authenticated: authenticated),
            body: body == null ? null : jsonEncode(body),
          )
          .timeout(requestTimeout);
      sw.stop();
      _logRequest('PATCH', url, sw.elapsed, response.statusCode);
      return _decodeResponse(response);
    } on TimeoutException {
      throw ApiException(0, 'Request timed out. Check your connection.');
    }
  }

  Future<dynamic> deleteJson(
    String path, {
    Map<String, dynamic>? queryParameters,
    bool authenticated = true,
  }) async {
    try {
      final url = uri(path, queryParameters);
      final sw = Stopwatch()..start();
      final response = await http
          .delete(url, headers: await headers(authenticated: authenticated))
          .timeout(requestTimeout);
      sw.stop();
      _logRequest('DELETE', url, sw.elapsed, response.statusCode);
      return _decodeResponse(response);
    } on TimeoutException {
      throw ApiException(0, 'Request timed out. Check your connection.');
    }
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
