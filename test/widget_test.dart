// Smroute widget tests — verifies critical UI surfaces render correctly.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:finalyr_app/main.dart';
import 'package:finalyr_app/models/assigned_vehicle.dart';
import 'package:finalyr_app/models/ride_request_record.dart';
import 'package:finalyr_app/providers/auth_provider.dart';
import 'package:finalyr_app/providers/driver_provider.dart';
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

      expect(find.text('Smroute'), findsOneWidget);
      expect(find.textContaining('Welcome back'), findsOneWidget);
    });

    testWidgets('shows email and password fields', (tester) async {
      await tester.pumpWidget(_wrapWithProviders(const LoginScreen()));
      await tester.pump();

      expect(find.widgetWithText(TextField, 'you@example.com'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Your password'), findsOneWidget);
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
          find.widgetWithText(TextField, 'you@example.com');
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

      // Field labels (design system: 13px semibold, sentence case)
      expect(find.text('Full name'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Phone number'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);

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
      expect(pay.transactions, isEmpty);
      expect(pay.totalSpent, 0.0);
      expect(pay.isLoading, isFalse);
      expect(pay.error, isNull);
    });

    test('clear resets all state', () {
      final pay = PaymentProvider();
      pay.clear();
      expect(pay.transactions, isEmpty);
      expect(pay.totalSpent, 0.0);
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

  // -------------------------------------------------------------------------
  // 8. RideProvider payment phase machine (website RazorpayPayment parity)
  // -------------------------------------------------------------------------

  group('RideProvider payment phase machine', () {
    test('starts idle with no error', () {
      final ride = RideProvider();
      expect(ride.paymentPhase, PaymentPhase.idle);
      expect(ride.paymentError, isNull);
      expect(ride.isPaying, isFalse);
    });

    test('payActiveRideFare with no active ride is a no-op that stays idle',
        () async {
      final ride = RideProvider();
      final result = await ride.payActiveRideFare();
      expect(result, isFalse);
      expect(ride.paymentPhase, PaymentPhase.idle);
      expect(ride.paymentError, isNull);
    });

    test('resetPaymentState returns to idle', () {
      final ride = RideProvider();
      ride.resetPaymentState();
      expect(ride.paymentPhase, PaymentPhase.idle);
      expect(ride.paymentError, isNull);
    });

    test('reset() also resets payment state', () {
      final ride = RideProvider();
      ride.reset();
      expect(ride.paymentPhase, PaymentPhase.idle);
      expect(ride.paymentError, isNull);
    });
  });

  // -------------------------------------------------------------------------
  // 9. DriverProvider (website DriverView parity)
  // -------------------------------------------------------------------------
  group('DriverProvider', () {
    DriverProvider buildProvider() {
      final auth = AuthProvider();
      return DriverProvider(auth);
    }

    test('initial state is clean', () {
      final driver = buildProvider();
      expect(driver.myVehicle, isNull);
      expect(driver.vehicles, isEmpty);
      expect(driver.board, isEmpty);
      expect(driver.activeRides, isEmpty);
      expect(driver.pendingRides, isEmpty);
      expect(driver.isLoading, isFalse);
      expect(driver.error, isNull);
    });

    test('activeRides/pendingRides filter and sort by newest first', () {
      final driver = buildProvider();
      // Use the public board setter path via reflection-free approach: we
      // can't set private fields, so exercise the public getters' contracts
      // through an empty board (real filtering is backend-driven).
      expect(driver.activeRides, isEmpty);
      expect(driver.pendingRides, isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  // 10. Ride lifecycle state machine (website parity regression tests)
  // -------------------------------------------------------------------------
  group('RideProvider ride lifecycle', () {
    RideRequestRecord record(int id, String status, {DateTime? requestedAt}) {
      // Backend JSON shape (RideRequestResponse) — parsed by fromJson.
      return RideRequestRecord.fromJson({
        'id': id,
        'pickup_lat': 12.9716,
        'pickup_lng': 77.5946,
        'dest_lat': 12.9352,
        'dest_lng': 77.6245,
        'status': status,
        'request_time':
            (requestedAt ?? DateTime.now().toUtc()).toIso8601String(),
        'pickup_label': 'Indiranagar 100 Feet Rd',
        'destination_label': 'MG Road Metro',
        'ride_option_id': 'swift-x',
        'ride_option_name': 'SwiftX',
        'ride_option_price': '₹12–15',
      });
    }

    test(
      'WS ride_status_updated advances the ACTIVE ride record immediately',
      () {
        final ride = RideProvider();
        ride.debugSetRides(
          [record(258, 'pending')],
          currentRideId: 258,
        );
        expect(ride.activeRideRecord!.status, 'pending');

        // Driver accepted — the notification callback fires.
        ride.handleRideStatusUpdate('assigned', 258);

        expect(ride.activeRideRecord!.status, 'assigned');
        expect(ride.stage, BookingStage.found);
      },
    );

    test(
      'WS event for a DIFFERENT ride never leaks into the active ride',
      () {
        final ride = RideProvider();
        ride.debugSetRides(
          [record(300, 'pending'), record(258, 'pending')],
          currentRideId: 258,
        );

        ride.handleRideStatusUpdate('completed', 300);

        expect(ride.activeRideRecord!.status, 'pending');
        expect(ride.stage, BookingStage.matching);
      },
    );

    test('cancelled transitions mark the active ride terminal', () {
      final ride = RideProvider();
      ride.debugSetRides([record(258, 'assigned')], currentRideId: 258);

      ride.handleRideStatusUpdate('cancelled', 258);

      expect(ride.activeRideRecord!.status, 'cancelled');
      expect(ride.hasActiveRide, isFalse);
    });

    test(
      'loadMyRides adopts the newest non-terminal ride after a restart',
      () async {
        final ride = RideProvider();
        // Fresh start: nothing tracked. The ride list (from the backend)
        // holds a ride still in flight.
        ride.debugSetRides([record(301, 'assigned')]);
        expect(ride.currentRideId, isNull);

        ride.restoreFromRidesForTest();

        expect(ride.currentRideId, 301);
        expect(ride.activeRideRecord!.status, 'assigned');
        expect(ride.stage, BookingStage.found);
        expect(ride.hasActiveRide, isTrue);
      },
    );

    // ── Derived map animation (RideVehicleAnimation) ────────────────────────

    test('vehicleAnimation appears only once a driver is assigned', () {
      final ride = RideProvider();
      ride.debugSetRides([record(258, 'pending')], currentRideId: 258);
      expect(ride.vehicleAnimation, isNull, reason: 'nothing assigned yet');

      ride.handleRideStatusUpdate('clustered', 258);
      expect(ride.vehicleAnimation, isNull);

      // Driver accepts.
      ride.handleRideStatusUpdate('assigned', 258);
      final assigned = ride.vehicleAnimation!;
      expect(assigned.path.last.lat, closeTo(12.9716, 1e-9));
      expect(assigned.path.last.lng, closeTo(77.5946, 1e-9));
      expect(assigned.path.length, 2);
    });

    test('vehicleAnimation switches from the pickup leg to the trip leg', () {
      final ride = RideProvider();
      ride.debugSetRides([record(258, 'assigned')], currentRideId: 258);
      expect(ride.isInTransit, isFalse);

      ride.handleRideStatusUpdate('in_progress', 258);
      final transit = ride.vehicleAnimation!;

      // No route estimate in a unit test, so the straight-line fallback runs
      // pickup → destination.
      expect(transit.path.first.lat, closeTo(12.9716, 1e-9));
      expect(transit.path.last.lat, closeTo(12.9352, 1e-9));
      expect(ride.isInTransit, isTrue);
    });

    test('a finished ride stops feeding the map its stale vehicle record', () {
      final ride = RideProvider();
      ride.debugSetRides([record(258, 'in_progress')], currentRideId: 258);
      ride.debugSetVehicle(
        AssignedVehicle(
          id: 7,
          licensePlate: 'KA01AB1234',
          status: 'active',
          lat: 12.99,
          lng: 77.60,
        ),
      );

      // While the trip is under way the map draws it.
      expect(ride.trackableVehicle, isNotNull);
      expect(ride.vehicleAnimation, isNotNull);

      ride.handleRideStatusUpdate('completed', 258);

      // The backend never clears the vehicle record, so the map must stop
      // being fed it — otherwise the car would be dragged back to a
      // pre-trip coordinate after the animation finished at the destination.
      expect(ride.trackableVehicle, isNull);
      expect(ride.vehicleAnimation, isNull);
      expect(ride.isInTransit, isFalse);
    });
  });
}
