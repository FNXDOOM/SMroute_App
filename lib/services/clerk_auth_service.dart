import 'dart:async';

import 'package:clerk_auth/clerk_auth.dart'
    show ApiResponse, Stage, Strategy;
import 'package:clerk_flutter/clerk_flutter.dart';

import '../config/app_env.dart';
import '../services/api_client.dart';

/// Result of a Clerk sign-in attempt.
class ClerkSignInResult {
  final bool success;
  final String? errorMessage;

  const ClerkSignInResult._({required this.success, this.errorMessage});

  const ClerkSignInResult.success() : this._(success: true);
  const ClerkSignInResult.failure(String message)
      : this._(success: false, errorMessage: message);
}

/// Clerk-backed email sign-in for accounts created on the WEBSITE (no
/// backend changes).
///
/// Website users keep their password in Clerk, and THIS Clerk instance has
/// password sign-in disabled (email one-time-code is the only first factor),
/// so the local POST /auth/login path 401s for them and AuthProvider falls
/// back to the emailed-code flow here:
///
///   1. [startEmailCodeSignIn] creates the Clerk SignIn and emails a 6-digit
///      code (idempotent: re-calls resend instead of silently doing nothing
///      when a verification is already pending).
///   2. [completeEmailCodeSignIn] verifies the code. On success the session
///      JWT is fetched fresh via [ClerkAuthState.sessionToken] (Clerk JWTs
///      are short-lived by design) and handed to the app's EXISTING session
///      machinery: ApiClient stores it and every request sends
///      `Authorization: Bearer <clerk jwt>`.
///   3. The existing backend verifies it (Clerk JWKS, RS256) — native
///      clients without an `azp` claim are allowed by
///      CLERK_ALLOW_NATIVE_CLIENTS=true — and auto-provisions/links the DB
///      user (passenger by default).
///
/// The [ClerkAuthState] is created eagerly in main() and attached here (also
/// passed to the ClerkAuth widget), because session tokens must be
/// refreshable OUTSIDE the widget tree (app boot, providers).
///
/// No second auth system: the app merely presents a Clerk session to the
/// same backend the website uses.
class ClerkAuthService {
  ClerkAuthService._();

  static ClerkAuthState? _state;

  /// The eagerly-created Clerk auth state (null when the build has no
  /// CLERK_PUBLISHABLE_KEY — backend-native email/password only).
  static ClerkAuthState? get state => _state;

  static void attach(ClerkAuthState? authState) {
    _state = authState;
    // Give every API request a way to ask for the CURRENT session token. Clerk
    // session JWTs expire in ~60s, so the token must be re-minted per request
    // (cheap: Clerk's SDK serves its own cached token until it nears expiry)
    // rather than read once at login/boot and replayed until it 401s.
    ApiClient.instance.setTokenRefresher(
      authState == null ? null : refreshSessionToken,
    );
  }

  /// Whether a Clerk session currently exists (SDK-persisted across restarts).
  static bool get hasClerkSession => _state?.isSignedIn ?? false;

  /// Returns a FRESH session JWT, or null when there is no live Clerk
  /// session. Called on app boot (session restore) because Clerk JWTs expire
  /// in ~60s — a stored token from a previous launch is always stale.
  static Future<String?> refreshSessionToken() async {
    final state = _state;
    if (state == null || !AppEnv.hasClerk) return null;
    try {
      if (!state.isSignedIn) return null;
      final sessionToken = await state.sessionToken();
      if (!sessionToken.isNotExpired) return null;
      return sessionToken.jwt;
    } on Exception {
      // No session / SDK not ready / network blip — caller falls back.
      return null;
    }
  }

  /// Step 1 of email-code sign-in: create the SignIn for [email] and send
  /// the 6-digit code to it.
  ///
  /// If a verification for the same identifier is already pending (user
  /// tapped "didn't get code" / restarted the flow), resends instead of
  /// becoming a silent no-op.
  static Future<ClerkSignInResult> startEmailCodeSignIn(String email) async {
    final state = _state;
    if (state == null || !AppEnv.hasClerk) {
      return const ClerkSignInResult.failure(
        'Email sign-in is not configured in this build.',
      );
    }
    try {
      final alreadyPending =
          state.signIn?.isVerifying(Stage.first, Strategy.emailCode) ?? false;
      if (alreadyPending) {
        final response = await state.resendCode(Strategy.emailCode);
        if (response.isOkay) return const ClerkSignInResult.success();
      }
      await state.attemptSignIn(
        strategy: Strategy.emailCode,
        identifier: email,
      );
    } on Exception catch (e) {
      // A failed attempt must not poison the next one.
      await state.resetClient();
      return ClerkSignInResult.failure(
        _friendlyMessage(e, fallback: 'Could not start email sign-in.'),
      );
    }
    final pending =
        state.signIn?.isVerifying(Stage.first, Strategy.emailCode) ?? false;
    if (!state.isSignedIn && !pending) {
      await state.resetClient();
      return const ClerkSignInResult.failure(
        'Email sign-in could not be started. Please try again.',
      );
    }
    return const ClerkSignInResult.success();
  }

  /// Step 2: verify the emailed [code]. On success transfers the Clerk
  /// session into the app's session machinery and validates the backend.
  static Future<ClerkSignInResult> completeEmailCodeSignIn(String code) async {
    final state = _state;
    if (state == null || !AppEnv.hasClerk) {
      return const ClerkSignInResult.failure(
        'Email sign-in is not configured in this build.',
      );
    }
    try {
      await state.attemptSignIn(
        strategy: Strategy.emailCode,
        code: code.trim(),
      );
    } on Exception catch (e) {
      return ClerkSignInResult.failure(
        _friendlyMessage(
          e,
          fallback: 'That code is not valid or has expired.',
        ),
      );
    }
    if (!state.isSignedIn) {
      return const ClerkSignInResult.failure(
        'Sign-in did not complete. Please try again.',
      );
    }
    return _exchangeSession(state);
  }

  /// Re-sends the pending email code. Returns true when the resend succeeded.
  static Future<bool> resendEmailCode() async {
    final state = _state;
    if (state == null) return false;
    try {
      final ApiResponse response = await state.resendCode(Strategy.emailCode);
      return response.isOkay;
    } on Exception {
      return false;
    }
  }

  /// Discards any pending (half-completed) Clerk sign-in attempt.
  static Future<void> cancelPendingSignIn() async {
    final state = _state;
    if (state == null || state.isSignedIn) return;
    try {
      await state.resetClient();
    } on Exception {
      // Best-effort cleanup.
    }
  }

  /// Transfers the live Clerk session into the app's session storage and
  /// validates it against the existing backend (provisions the DB user).
  static Future<ClerkSignInResult> _exchangeSession(ClerkAuthState state) async {
    try {
      final sessionToken = await state.sessionToken();
      final jwt = sessionToken.jwt;
      if (jwt.isEmpty) {
        return const ClerkSignInResult.failure(
          'Clerk session did not produce a token. Please try again.',
        );
      }
      await ApiClient.instance.setToken(jwt);

      // Validate against the existing backend + provision the DB user.
      final userJson = await ApiClient.instance.getJson('/auth/me');
      if (userJson is! Map<String, dynamic>) {
        await ApiClient.instance.clearToken();
        return const ClerkSignInResult.failure(
          'Backend rejected the Clerk session. Please try again.',
        );
      }
      return const ClerkSignInResult.success();
    } on ApiException catch (e) {
      await ApiClient.instance.clearToken();
      if (e.statusCode == 401 || e.statusCode == 403) {
        return const ClerkSignInResult.failure(
          'Backend rejected the Clerk session. Please try again.',
        );
      }
      // Backend unreachable: keep the token so restoreSession() retries it
      // on next launch (consistent with the app's transient-failure rule).
      return ClerkSignInResult.failure(
        'Signed in, but the server is unreachable (${e.message}). '
        'Please try again.',
      );
    } on Exception catch (e) {
      return ClerkSignInResult.failure(
        _friendlyMessage(e, fallback: 'Sign-in did not complete. Please try again.'),
      );
    }
  }

  /// Signs out of Clerk (all sessions) when a Clerk session exists. Safe to
  /// call for backend-native users — no-op when there is no Clerk session.
  static Future<void> signOut() async {
    final state = _state;
    if (state == null || !state.isSignedIn) return;
    try {
      await state.signOut();
    } on Exception {
      // Best-effort: local token is cleared regardless.
    }
  }

  /// Maps raw SDK/backend exceptions to user-facing messages.
  /// Never echoes token material.
  static String _friendlyMessage(Object e, {required String fallback}) {
    final raw = e.toString();
    if (raw.contains('cancelled') || raw.contains('canceled')) {
      return 'Sign-in was cancelled.';
    }
    if (raw.contains('network') ||
        raw.contains('Socket') ||
        raw.contains('Failed host lookup')) {
      return 'Network error during sign-in. Check your connection.';
    }
    return fallback;
  }
}
