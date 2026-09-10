import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/ride_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/payment_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/ride/ride_confirm_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/ride/ride_select_screen.dart';
import 'screens/ride/rating_screen.dart';
import 'screens/inbox/inbox_screen.dart';
import 'screens/payment/payment_screen.dart';
import 'screens/trips/trips_screen.dart';
import 'screens/profile/profile_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
            title: 'SmartRoute',
            theme: AppTheme.dark,
            debugShowCheckedModeBanner: false,
            initialRoute: '/',
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
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🚗', style: TextStyle(fontSize: 48)),
              SizedBox(height: 24),
              CircularProgressIndicator(color: AppTheme.accentBlue),
            ],
          ),
        ),
      );
    }

    // Session restore complete — navigate once, without keeping this in stack.
    _routeAfterBootstrap(auth.isAuthenticated);

    // Show nothing while the post-frame callback fires.
    return const Scaffold(backgroundColor: Colors.black);
  }
}
