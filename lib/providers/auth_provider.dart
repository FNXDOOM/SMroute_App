import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/user.dart';
import '../services/api_client.dart';

/// Email format used for lightweight client-side validation.
final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

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
    if (token == null || token.isEmpty) {
      throw const FormatException('Missing access_token in response');
    }
    await _api.setToken(token);

    final userJson = payload['user'];
    if (userJson is! Map<String, dynamic>) {
      // Token is valid but user payload is malformed — don't leave a
      // half-logged-in state (token saved, no user, no error).
      await _api.clearToken();
      throw const FormatException('Missing user in response');
    }
    _currentUser = AppUser.fromJson(userJson, phoneFallback: phoneFallback);
    // Preserve a locally-known phone when the backend omits it.
    if (_currentUser!.phone.isEmpty && phoneFallback.isNotEmpty) {
      _currentUser = _currentUser!.copyWithPhone(phoneFallback);
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
      if (userJson is! Map<String, dynamic>) {
        throw const FormatException('Invalid /auth/me response');
      }
      _currentUser = AppUser.fromJson(userJson);
    } on ApiException catch (e) {
      // Only wipe the stored token when the backend actively rejects it.
      // Transient network failures (status 0) or 5xx must keep the session
      // so the next launch can retry instead of forcing a re-login.
      if (e.isUnauthorized) {
        try {
          await _api.clearToken();
        } catch (_) {
          // Clearing prefs must never crash bootstrap.
        }
        _currentUser = null;
      }
      // On network/server errors _currentUser stays null for this launch,
      // but the token is preserved for a later retry.
      if (_currentUser == null && !e.isUnauthorized) {
        _error = e.message;
      }
    } catch (_) {
      // Malformed payload etc. — keep token, surface nothing fatal here.
      _currentUser = null;
    } finally {
      _isBootstrapping = false;
      notifyListeners();
    }
  }

  String? _validateLogin(String email, String password) {
    if (_hasEmptyFields([email, password])) {
      return 'Please fill in all fields.';
    }
    if (!_emailPattern.hasMatch(email.trim())) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  Future<void> login(String email, String password) async {
    final validationError = _validateLogin(email, password);
    if (validationError != null) {
      _error = validationError;
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
      if (response is! Map<String, dynamic>) {
        throw const FormatException('Invalid login response');
      }
      await _applyTokenResponse(response);
    } on FormatException {
      _error = 'Unexpected server response. Please try again.';
    } catch (error) {
      _error = _messageForException(error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  String? _validateRegister(
    String name,
    String email,
    String phone,
    String password,
  ) {
    if (_hasEmptyFields([name, email, phone, password])) {
      return 'Please fill in all fields.';
    }
    if (!_emailPattern.hasMatch(email.trim())) {
      return 'Enter a valid email address.';
    }
    if (password.length < 6) {
      return 'Password must be at least 6 characters.';
    }
    return null;
  }

  Future<void> register(
    String name,
    String email,
    String phone,
    String password,
  ) async {
    final validationError = _validateRegister(name, email, phone, password);
    if (validationError != null) {
      _error = validationError;
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
          'phone': phone.trim(),
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
      if (loginResponse is! Map<String, dynamic>) {
        throw const FormatException('Invalid login response');
      }
      await _applyTokenResponse(
        loginResponse,
        phoneFallback: phone.trim(),
      );
    } on FormatException {
      _error = 'Unexpected server response. Please try again.';
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
    if (name.trim().isEmpty) return 'Name is required.';
    if (!_emailPattern.hasMatch(email.trim())) return 'Enter a valid email.';

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
      if (response is! Map<String, dynamic>) {
        throw const FormatException('Invalid profile response');
      }
      _currentUser = AppUser.fromJson(response);
      return null; // success
    } on FormatException {
      _error = 'Unexpected server response. Please try again.';
      return _error;
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
    try {
      await _api.clearToken();
    } catch (_) {
      // Prefs failures must not block logout.
    }
    _currentUser = null;
    _error = null;
    notifyListeners();
  }
}
