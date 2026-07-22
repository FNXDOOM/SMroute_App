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
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => PaymentProvider()),
      ],
      // Use Builder instead of Consumer so MaterialApp is only built once.
      // Auth guard is handled in onGenerateRoute by reading the provider lazily.
      child: Builder(
        builder: (context) {
          return MaterialApp(
            title: 'SmartRoute',
            theme: AppTheme.dark,
            debugShowCheckedModeBanner: false,
            initialRoute: '/',
            routes: {
              '/': (_) => const LoginScreen(),
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
              final publicRoutes = {'/', '/register'};
              final auth = Provider.of<AuthProvider>(context, listen: false);
              if (!auth.isAuthenticated &&
                  !publicRoutes.contains(settings.name)) {
                return MaterialPageRoute(
                  builder: (_) => const LoginScreen(),
                  settings: const RouteSettings(name: '/'),
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

// No placeholder needed — all routes use real screens.
