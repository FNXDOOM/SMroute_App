import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/app_env.dart';
import '../models/user.dart';
import '../services/api_client.dart';
import '../services/clerk_auth_service.dart';

/// Email format used for lightweight client-side validation.
final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

class AuthProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient.instance;

  AppUser? _currentUser;
  bool _isLoading = false;
  bool _isBootstrapping = true;
  String? _error;

  // Two-step email sign-in for website accounts (Clerk emailed code).
  bool _awaitingEmailCode = false;
  String _pendingEmail = '';

  AuthProvider() {
    unawaited(restoreSession());
  }

  // Getters
  AppUser? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isBootstrapping => _isBootstrapping;
  String? get error => _error;

  /// Clears the last error (used when navigating between auth screens so a
  /// login failure doesn't render on the register screen).
  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }
  bool get isAuthenticated => _currentUser != null;
  bool get isAwaitingEmailCode => _awaitingEmailCode;
  String get pendingEmail => _pendingEmail;

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
      var token = await _api.token;

      // Clerk sessions (website-account email fallback) use short-lived
      // JWTs (~60s) — a token persisted from a previous launch is always
      // stale. When a live Clerk session exists, always mint a fresh one
      // instead.
      if (ClerkAuthService.state != null) {
        final clerkJwt = await ClerkAuthService.refreshSessionToken();
        if (clerkJwt != null && clerkJwt.isNotEmpty) {
          token = clerkJwt;
          await _api.setToken(clerkJwt);
        }
      }

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
      // Accounts created on the WEBSITE keep their password in Clerk — the
      // backend's users table holds an unusable random hash for them, so
      // /auth/login 401s even for a correct password. This Clerk instance
      // uses emailed one-time codes as its only first factor (password
      // sign-in is disabled), so fall back to the email-code flow: send a
      // code to the entered email and wait for the user to type it in.
      if (error is ApiException &&
          error.isUnauthorized &&
          AppEnv.hasClerk &&
          ClerkAuthService.state != null) {
        final result = await ClerkAuthService.startEmailCodeSignIn(
          email.trim(),
        );
        if (result.success) {
          _awaitingEmailCode = true;
          _pendingEmail = email.trim();
          _error = null;
        } else {
          _error = result.errorMessage;
        }
      } else {
        _error = _messageForException(error);
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Step 2 of website-account sign-in: verify the 6-digit code emailed by
  /// Clerk. On success loads the user via /auth/me (which provisions/links
  /// the DB user) and clears the pending-code state.
  Future<void> verifyEmailCode(String code) async {
    if (code.trim().isEmpty) {
      _error = 'Enter the 6-digit code from your email.';
      notifyListeners();
      return;
    }
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await ClerkAuthService.completeEmailCodeSignIn(code);
      if (result.success) {
        await restoreSession();
        if (_currentUser != null) {
          _awaitingEmailCode = false;
          _pendingEmail = '';
        }
      } else {
        _error = result.errorMessage;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Re-sends the pending 6-digit code ("Didn't get the code?").
  Future<void> resendEmailCode() async {
    if (!_awaitingEmailCode) return;
    final ok = await ClerkAuthService.resendEmailCode();
    _error = ok ? null : "Couldn't resend the code. Try starting again.";
    notifyListeners();
  }

  /// Abandons the email-code step and returns to plain email/password mode.
  Future<void> cancelEmailCode() async {
    await ClerkAuthService.cancelPendingSignIn();
    _awaitingEmailCode = false;
    _pendingEmail = '';
    _error = null;
    notifyListeners();
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

  /// Updates the current user's profile.
  ///
  /// Only name and phone are writable — the website's ProfileView does the
  /// same (`authApi.updateProfile({ name, phone })`). Email belongs to the
  /// identity provider (Clerk), so writing it locally would desync the account
  /// from the identity its token is issued for.
  Future<String?> updateProfile({
    required String name,
    required String phone,
  }) async {
    if (name.trim().isEmpty) return 'Name is required.';

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.patchJson(
        '/auth/me',
        body: {
          'name': name.trim(),
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

  /// Clears the current user session. For Clerk sessions (website-account
  /// email fallback) this also signs out of Clerk; backend-native
  /// email/password users are unaffected.
  Future<void> logout() async {
    try {
      await ClerkAuthService.signOut();
    } catch (_) {
      // Best-effort — token clearing below must always run.
    }
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
