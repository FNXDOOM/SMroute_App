import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  ApiClient._({String? baseUrl})
      : baseUrl = (baseUrl ?? const String.fromEnvironment(
          'SMARTROUTE_API_BASE_URL',
          defaultValue: 'http://127.0.0.1:8000',
        )).replaceAll(RegExp(r'/$'), '');

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

  Future<dynamic> getJson(
    String path, {
    Map<String, dynamic>? queryParameters,
    bool authenticated = true,
  }) async {
    final response = await http.get(
      uri(path, queryParameters),
      headers: await headers(authenticated: authenticated),
    );
    return _decodeResponse(response);
  }

  Future<dynamic> postJson(
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParameters,
    bool authenticated = true,
  }) async {
    final response = await http.post(
      uri(path, queryParameters),
      headers: await headers(authenticated: authenticated),
      body: body == null ? null : jsonEncode(body),
    );
    return _decodeResponse(response);
  }

  Future<dynamic> patchJson(
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParameters,
    bool authenticated = true,
  }) async {
    final response = await http.patch(
      uri(path, queryParameters),
      headers: await headers(authenticated: authenticated),
      body: body == null ? null : jsonEncode(body),
    );
    return _decodeResponse(response);
  }

  Future<dynamic> deleteJson(
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParameters,
    bool authenticated = true,
  }) async {
    final response = await http.delete(
      uri(path, queryParameters),
      headers: await headers(authenticated: authenticated),
      body: body == null ? null : jsonEncode(body),
    );
    return _decodeResponse(response);
  }

  dynamic _decodeResponse(http.Response response) {
    final body = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    final message = switch (body) {
      Map<String, dynamic> data when data['detail'] != null => data['detail'].toString(),
      _ => body?.toString() ?? 'Request failed with status ${response.statusCode}',
    };
    throw ApiException(response.statusCode, message);
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode, $message)';
}
