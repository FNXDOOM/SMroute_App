/// Build-time environment for the app.
///
/// All values are PUBLIC client configuration (safe to ship in the binary):
/// - SMARTROUTE_API_BASE_URL: backend origin (no secrets).
/// - CLERK_PUBLISHABLE_KEY: Clerk's publishable key (`pk_...`) — the same key
///   the website ships in its browser bundle. Required for the Clerk email
///   sign-in fallback (accounts created on the WEBSITE keep their password in
///   Clerk; the backend validates the Clerk JWT — CLERK_ALLOW_NATIVE_CLIENTS
///   =true must be set in backend/.env).
///
/// Provide via --dart-define or --dart-define-from-file=config.prod.json:
///   { "CLERK_PUBLISHABLE_KEY": "pk_test_..." }
class AppEnv {
  AppEnv._();

  static const String apiBaseUrl = String.fromEnvironment(
    'SMARTROUTE_API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  static const String clerkPublishableKey =
      String.fromEnvironment('CLERK_PUBLISHABLE_KEY');

  /// True when Clerk-backed email sign-in (website-account fallback) is
  /// available in this build.
  static bool get hasClerk => clerkPublishableKey.isNotEmpty;
}
