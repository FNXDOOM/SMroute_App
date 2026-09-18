import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'config/app_env.dart';
import 'services/clerk_auth_service.dart';
import 'theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/driver_provider.dart';
import 'providers/ride_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/payment_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/driver/driver_apply_screen.dart';
import 'screens/driver/driver_console_screen.dart';
import 'screens/ride/ride_confirm_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/ride/ride_select_screen.dart';
import 'screens/ride/rating_screen.dart';
import 'screens/inbox/inbox_screen.dart';
import 'screens/payment/payment_screen.dart';
import 'screens/trips/trips_screen.dart';
import 'screens/profile/profile_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Clerk is initialized eagerly so session tokens can be refreshed outside
  // the widget tree (app boot / session restore). Requires
  // CLERK_PUBLISHABLE_KEY via --dart-define / --dart-define-from-file
  // (see lib/config/app_env.dart). Clerk-backed email sign-in (for accounts
  // created on the website) is enabled when the key exists; a broken or
  // unreachable Clerk config falls back to backend-native email/password
  // without bricking the app.
  if (AppEnv.hasClerk) {
    try {
      ClerkAuthService.attach(
        await ClerkAuthState.create(
          config: ClerkAuthConfig(
            publishableKey: AppEnv.clerkPublishableKey,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Clerk init failed; Clerk sign-in fallback disabled (${e.runtimeType})');
      ClerkAuthService.attach(null);
    }
  }

  runApp(const SmartRouteApp());
}

class SmartRouteApp extends StatelessWidget {
  const SmartRouteApp({super.key});

  static const _publicRoutes = {'/', '/login', '/register'};

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => RideProvider()),
        ChangeNotifierProxyProvider<AuthProvider, DriverProvider>(
          create: (context) =>
              DriverProvider(context.read<AuthProvider>()),
          update: (_, auth, driver) {
            if (driver == null) {
              return DriverProvider(auth);
            }
            // Rebuild the provider's view of the user on login/logout.
            return driver..refreshAuth(auth);
          },
        ),
        ChangeNotifierProxyProvider<RideProvider, NotificationProvider>(
          create: (_) => NotificationProvider(),
          update: (_, rideProvider, notifProvider) {
            notifProvider ??= NotificationProvider();
            notifProvider.onRideStatusUpdated = rideProvider.handleRideStatusUpdate;
            return notifProvider;
          },
        ),
        ChangeNotifierProvider(create: (_) => PaymentProvider()),
      ],
      child: Builder(
        builder: (context) {
          return MaterialApp(
            title: 'Smroute',
            theme: AppTheme.dark,
            debugShowCheckedModeBanner: false,
            initialRoute: '/',
            // When Clerk is configured, wrap the navigator in ClerkAuth
            // (required for the SDK's context lookups). It reuses
            // the eagerly-created auth state — no second instance.
            //
            // Pass `authState` ONLY: ClerkAuth asserts exactly one of
            // `config`/`authState` (config == null) != (authState == null), and
            // the state created in main() already carries the config
            // (ClerkAuth.config falls back to authState!.config). Passing both
            // tripped that assert and showed the red error screen on launch.
            // When Clerk is not configured, builder stays null (plain app) and
            // Clerk-backed sign-in is disabled (AppEnv.hasClerk == false).
            builder: AppEnv.hasClerk && ClerkAuthService.state != null
                ? (navContext, child) => ClerkAuth(
                    authState: ClerkAuthService.state,
                    child: child ?? const SizedBox.shrink(),
                  )
                : null,
            // NOTE: auth guard lives in onGenerateRoute. Do NOT also use
            // `routes:` — entries there take precedence and would bypass
            // the guard (previous bug: guard never fired).
            onGenerateRoute: (settings) {
              final auth = Provider.of<AuthProvider>(context, listen: false);
              final name = settings.name ?? '/';
              if (!auth.isAuthenticated &&
                  !auth.isBootstrapping &&
                  !_publicRoutes.contains(name)) {
                return MaterialPageRoute(
                  builder: (_) => const LoginScreen(),
                  settings: const RouteSettings(name: '/login'),
                );
              }
              return MaterialPageRoute(
                settings: settings,
                builder: (_) {
                  switch (name) {
                    case '/':
                      return const _BootstrapScreen();
                    case '/login':
                      return const LoginScreen();
                    case '/register':
                      return const RegisterScreen();
                    case '/home':
                      return const HomeScreen();
                    case '/ride-select':
                      return const RideSelectScreen();
                    case '/ride-confirm':
                      return const RideConfirmScreen();
                    case '/rating':
                      return const RatingScreen();
                    case '/inbox':
                      return const InboxScreen();
                    case '/trips':
                      return const TripsScreen();
                    case '/payment':
                      return const PaymentScreen();
                    case '/profile':
                      return const ProfileScreen();
                    case '/driver':
                      return const DriverConsoleScreen();
                    case '/driver-apply':
                      return const DriverApplyScreen();
                    default:
                      return const _BootstrapScreen();
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}

/// Waits for the stored session to be validated, then routes accordingly.
class _BootstrapScreen extends StatefulWidget {
  const _BootstrapScreen();

  @override
  State<_BootstrapScreen> createState() => _BootstrapScreenState();
}

class _BootstrapScreenState extends State<_BootstrapScreen> {
  bool _navigated = false;

  void _routeAfterBootstrap(bool isAuthenticated) {
    if (_navigated || !mounted) return;
    _navigated = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        isAuthenticated ? '/home' : '/login',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.isBootstrapping) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Brand mark — line icon on the site's black/white palette.
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.paper,
                  borderRadius: AppRadius.all(AppRadius.lg),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.route,
                  size: 26,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 24),
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: AppColors.paper,
                  strokeWidth: 2,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Session restore complete — navigate once, without keeping this in stack.
    _routeAfterBootstrap(auth.isAuthenticated);

    // Show nothing while the post-frame callback fires.
    return const Scaffold(backgroundColor: AppColors.bg);
  }
}
