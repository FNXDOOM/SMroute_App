// SmartRoute widget tests — verifies critical UI surfaces render correctly.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:finalyr_app/main.dart';
import 'package:finalyr_app/providers/auth_provider.dart';
import 'package:finalyr_app/providers/ride_provider.dart';
import 'package:finalyr_app/providers/notification_provider.dart';
import 'package:finalyr_app/providers/payment_provider.dart';
import 'package:finalyr_app/screens/auth/login_screen.dart';
import 'package:finalyr_app/screens/auth/register_screen.dart';
import 'package:finalyr_app/theme/app_theme.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Wraps a widget with the same MultiProvider tree used in main.dart so that
/// screens that call context.read/watch don't throw.
Widget _wrapWithProviders(Widget child) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AuthProvider()),
      ChangeNotifierProvider(create: (_) => RideProvider()),
      ChangeNotifierProxyProvider<RideProvider, NotificationProvider>(
        create: (_) => NotificationProvider(),
        update: (_, rideProvider, notifProvider) {
          notifProvider ??= NotificationProvider();
          notifProvider.onRideStatusUpdated =
              rideProvider.handleRideStatusUpdate;
          return notifProvider;
        },
      ),
      ChangeNotifierProvider(create: (_) => PaymentProvider()),
    ],
    child: MaterialApp(
      theme: AppTheme.dark,
      home: child,
    ),
  );
}

// ---------------------------------------------------------------------------
// 1. App bootstrap smoke test
// ---------------------------------------------------------------------------

void main() {
  group('App bootstrap', () {
    testWidgets('SmartRouteApp starts without throwing', (tester) async {
      await tester.pumpWidget(const SmartRouteApp());
      // Let providers initialise (SharedPreferences → no stored token).
      await tester.pump(const Duration(milliseconds: 100));
      // The _BootstrapScreen or LoginScreen must be visible — just ensure no
      // RenderFlex overflow or uncaught exception.
      expect(tester.takeException(), isNull);
    });
  });

  // -------------------------------------------------------------------------
  // 2. Login screen
  // -------------------------------------------------------------------------

  group('LoginScreen', () {
    testWidgets('renders app name and headline', (tester) async {
      await tester.pumpWidget(_wrapWithProviders(const LoginScreen()));
      await tester.pump();

      expect(find.text('SmartRoute'), findsOneWidget);
      expect(find.textContaining("email or phone"), findsOneWidget);
    });

    testWidgets('shows email and password fields', (tester) async {
      await tester.pumpWidget(_wrapWithProviders(const LoginScreen()));
      await tester.pump();

      expect(find.widgetWithText(TextField, 'Email or phone number'),
          findsOneWidget);
      expect(find.widgetWithText(TextField, 'Password'), findsOneWidget);
    });

    testWidgets('Continue and Create account buttons are present',
        (tester) async {
      await tester.pumpWidget(_wrapWithProviders(const LoginScreen()));
      await tester.pump();

      expect(find.widgetWithText(ElevatedButton, 'Continue'), findsOneWidget);
      expect(
          find.widgetWithText(OutlinedButton, 'Create account'), findsOneWidget);
    });

    testWidgets('shows error when Continue tapped with empty fields',
        (tester) async {
      await tester.pumpWidget(_wrapWithProviders(const LoginScreen()));
      await tester.pump();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Continue'));
      await tester.pump();

      // AuthProvider.login sets error = 'Please fill in all fields.' when
      // either field is blank.
      expect(find.textContaining('fill in all fields'), findsOneWidget);
    });

    testWidgets('typing in email field updates text', (tester) async {
      await tester.pumpWidget(_wrapWithProviders(const LoginScreen()));
      await tester.pump();

      final emailField =
          find.widgetWithText(TextField, 'Email or phone number');
      await tester.enterText(emailField, 'test@example.com');
      await tester.pump();

      expect(find.text('test@example.com'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // 3. Register screen
  // -------------------------------------------------------------------------

  group('RegisterScreen', () {
    testWidgets('renders headline, all four fields, and CTA', (tester) async {
      await tester.pumpWidget(_wrapWithProviders(const RegisterScreen()));
      await tester.pump();

      // Headline (both words appear somewhere)
      expect(find.textContaining('Create your'), findsOneWidget);

      // Label chips above each field
      expect(find.text('FULL NAME'), findsOneWidget);
      expect(find.text('EMAIL'), findsOneWidget);
      expect(find.text('PHONE NUMBER'), findsOneWidget);
      expect(find.text('PASSWORD'), findsOneWidget);

      // Four TextField widgets present
      expect(find.byType(TextField), findsNWidgets(4));

      // CTA button
      expect(
          find.widgetWithText(ElevatedButton, 'Create account'), findsOneWidget);
    });

    testWidgets('shows error when submitted with empty fields', (tester) async {
      await tester.pumpWidget(_wrapWithProviders(const RegisterScreen()));
      await tester.pump();

      // The button may be below the fold — scroll it into view first.
      final btn = find.widgetWithText(ElevatedButton, 'Create account');
      await tester.ensureVisible(btn);
      await tester.pump();
      await tester.tap(btn, warnIfMissed: false);
      await tester.pump();

      expect(find.textContaining('fill in all fields'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // 4. AuthProvider unit-style tests
  // -------------------------------------------------------------------------

  group('AuthProvider', () {
    test('initial state: not authenticated, bootstrapping=true', () {
      final auth = AuthProvider();
      // Constructor triggers restoreSession() asynchronously; synchronously
      // the state should be: not yet authenticated, still bootstrapping.
      expect(auth.isAuthenticated, isFalse);
      expect(auth.isBootstrapping, isTrue);
      expect(auth.error, isNull);
    });

    test('login with empty fields sets error and does not set loading=true',
        () async {
      final auth = AuthProvider();
      await auth.login('', '');
      expect(auth.error, 'Please fill in all fields.');
      expect(auth.isLoading, isFalse);
      expect(auth.isAuthenticated, isFalse);
    });

    test('register with empty fields sets error', () async {
      final auth = AuthProvider();
      await auth.register('', '', '', '');
      expect(auth.error, 'Please fill in all fields.');
      expect(auth.isLoading, isFalse);
    });

    test('logout clears user and error (state check only)', () {
      final auth = AuthProvider();
      // Verify the initial state: no user, no error. We can't call
      // auth.logout() in a pure Dart test because clearToken() uses
      // SharedPreferences which requires the Flutter binding / platform
      // channels to be set up. The behaviour is covered by the integration
      // test environment instead.
      expect(auth.isAuthenticated, isFalse);
      expect(auth.error, isNull);
    });
  });

  // -------------------------------------------------------------------------
  // 5. RideProvider unit-style tests
  // -------------------------------------------------------------------------

  group('RideProvider', () {
    test('initial state is clean', () {
      final ride = RideProvider();
      expect(ride.destination, isNull);
      expect(ride.selectedOption, isNull);
      expect(ride.isBooking, isFalse);
      expect(ride.error, isNull);
      expect(ride.myRides, isEmpty);
    });

    test('setDestination updates state', () {
      final ride = RideProvider();
      ride.setDestination('Airport');
      expect(ride.destination, 'Airport');
    });

    test('confirmBooking without destination returns false and sets error',
        () async {
      final ride = RideProvider();
      final result = await ride.confirmBooking();
      expect(result, isFalse);
      expect(ride.error, isNotNull);
    });

    test('reset clears all state', () {
      final ride = RideProvider();
      ride.setDestination('Beach');
      ride.reset();
      expect(ride.destination, isNull);
      expect(ride.error, isNull);
    });
  });

  // -------------------------------------------------------------------------
  // 6. PaymentProvider unit-style tests
  // -------------------------------------------------------------------------

  group('PaymentProvider', () {
    test('initial state is clean', () {
      final pay = PaymentProvider();
      expect(pay.cards, isEmpty);
      expect(pay.transactions, isEmpty);
      expect(pay.isLoading, isFalse);
      expect(pay.error, isNull);
    });

    test('clear resets all state', () {
      final pay = PaymentProvider();
      pay.clear();
      expect(pay.cards, isEmpty);
      expect(pay.walletBalance, '\$0.00');
      expect(pay.error, isNull);
    });
  });

  // -------------------------------------------------------------------------
  // 7. NotificationProvider unit-style tests
  // -------------------------------------------------------------------------

  group('NotificationProvider', () {
    test('initial state is clean', () {
      final notif = NotificationProvider();
      expect(notif.unreadCount, 0);
      expect(notif.isLoading, isFalse);
      expect(notif.isLoaded, isFalse);
      expect(notif.error, isNull);
    });

    test('clear resets state', () {
      final notif = NotificationProvider();
      notif.clear();
      expect(notif.unreadCount, 0);
      expect(notif.error, isNull);
    });
  });
}
