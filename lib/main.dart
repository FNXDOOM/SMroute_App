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
            routes: {
              '/': (_) => const _BootstrapScreen(),
              '/login': (_) => const LoginScreen(),
              '/register': (_) => const RegisterScreen(),
              '/home': (_) => const HomeScreen(),
              '/ride-select': (_) => const RideSelectScreen(),
              '/ride-confirm': (_) => const RideConfirmScreen(),
              '/rating': (_) => const RatingScreen(),
              '/inbox': (_) => const InboxScreen(),
              '/trips': (_) => const TripsScreen(),
              '/payment': (_) => const PaymentScreen(),
              '/profile': (_) => const ProfileScreen(),
            },
            onGenerateRoute: (settings) {
              final publicRoutes = {'/', '/login', '/register'};
              final auth = Provider.of<AuthProvider>(context, listen: false);
              if (!auth.isAuthenticated &&
                  !auth.isBootstrapping &&
                  !publicRoutes.contains(settings.name)) {
                return MaterialPageRoute(
                  builder: (_) => const LoginScreen(),
                  settings: const RouteSettings(name: '/login'),
                );
              }
              return null;
            },
          );
        },
      ),
    );
  }
}

/// Waits for the stored session to be validated, then routes accordingly.
class _BootstrapScreen extends StatelessWidget {
  const _BootstrapScreen();

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

    // Session restore complete — navigate without keeping this in the stack.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushReplacementNamed(
        context,
        auth.isAuthenticated ? '/home' : '/login',
      );
    });

    // Show nothing while the post-frame callback fires.
    return const Scaffold(backgroundColor: Colors.black);
  }
}
