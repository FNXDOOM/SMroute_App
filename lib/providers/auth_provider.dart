import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/user.dart';
import '../services/api_client.dart';

class AuthProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient.instance;

  AppUser? _currentUser;
  bool _isLoading = false;
  bool _isBootstrapping = true;
  String? _error;

  AuthProvider() {
    unawaited(restoreSession());
  }

  // Getters
  AppUser? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isBootstrapping => _isBootstrapping;
  String? get error => _error;
  bool get isAuthenticated => _currentUser != null;

  /// Validates that none of the provided fields are empty or whitespace-only.
  bool _hasEmptyFields(List<String> fields) {
    return fields.any((f) => f.trim().isEmpty);
  }

  String _messageForException(Object error) {
    if (error is ApiException) return error.message;
    return 'Something went wrong. Please try again.';
  }

  Future<void> _applyTokenResponse(
    Map<String, dynamic> payload, {
    String phoneFallback = '',
  }) async {
    final token = payload['access_token']?.toString();
    if (token != null && token.isNotEmpty) {
      await _api.setToken(token);
    }

    final userJson = payload['user'];
    if (userJson is Map<String, dynamic>) {
      _currentUser = AppUser.fromJson(userJson, phoneFallback: phoneFallback);
    }
  }

  Future<void> restoreSession() async {
    _isBootstrapping = true;
    notifyListeners();

    try {
      await _api.initialize();
      final token = await _api.token;
      if (token == null || token.isEmpty) {
        _currentUser = null;
        return;
      }

      final userJson = await _api.getJson('/auth/me');
      _currentUser = AppUser.fromJson(userJson as Map<String, dynamic>);
    } catch (_) {
      await _api.clearToken();
      _currentUser = null;
    } finally {
      _isBootstrapping = false;
      notifyListeners();
    }
  }

  Future<void> login(String email, String password) async {
    if (_hasEmptyFields([email, password])) {
      _error = 'Please fill in all fields.';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.postJson(
        '/auth/login',
        authenticated: false,
        body: {
          'email': email.trim(),
          'password': password,
        },
      );
      await _applyTokenResponse(response as Map<String, dynamic>);
    } catch (error) {
      _error = _messageForException(error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> register(
    String name,
    String email,
    String phone,
    String password,
  ) async {
    if (_hasEmptyFields([name, email, phone, password])) {
      _error = 'Please fill in all fields.';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _api.postJson(
        '/auth/register',
        authenticated: false,
        body: {
          'name': name.trim(),
          'email': email.trim(),
          'password': password,
          'role': 'passenger',
        },
      );

      final loginResponse = await _api.postJson(
        '/auth/login',
        authenticated: false,
        body: {
          'email': email.trim(),
          'password': password,
        },
      );
      await _applyTokenResponse(
        loginResponse as Map<String, dynamic>,
        phoneFallback: phone.trim(),
      );
      _currentUser = _currentUser?.copyWithPhone(phone.trim()) ??
          AppUser(
            name: name.trim(),
            email: email.trim(),
            phone: phone.trim(),
          );
    } catch (error) {
      _error = _messageForException(error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Updates the current user's profile (name, email, phone).
  Future<String?> updateProfile({
    required String name,
    required String email,
    required String phone,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.patchJson(
        '/auth/me',
        body: {
          'name': name.trim(),
          'email': email.trim(),
          'phone': phone.trim(),
        },
      );
      _currentUser = AppUser.fromJson(response as Map<String, dynamic>);
      return null; // success
    } catch (error) {
      _error = _messageForException(error);
      return _error;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clears the current user session.
  Future<void> logout() async {
    await _api.clearToken();
    _currentUser = null;
    _error = null;
    notifyListeners();
  }
}
