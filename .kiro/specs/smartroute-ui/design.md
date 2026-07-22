# Design Document — SmartRoute UI

## Overview

SmartRoute is a Flutter ride-hailing app UI built to mirror a dark Uber-like React/TSX prototype. The implementation uses Flutter + Material 3, the `provider` package for state management, and fully mock data — no real maps SDK or backend calls are made. The design achieves pixel-fidelity to the reference by centralising all design tokens in `AppTheme` and using custom `CustomPainter` widgets for map illustrations.

---

## Architecture

### High-Level Layers

```
┌─────────────────────────────────────────┐
│               UI Layer                  │
│  Screens + Shared Widgets               │
└──────────────┬──────────────────────────┘
               │ context.watch / context.read
┌──────────────▼──────────────────────────┐
│           Provider Layer                │
│  AuthProvider  RideProvider             │
│  NotificationProvider  PaymentProvider  │
└──────────────┬──────────────────────────┘
               │ operates on
┌──────────────▼──────────────────────────┐
│            Model Layer                  │
│  AppUser  RideOption  Trip              │
│  AppNotification  PaymentCard           │
└─────────────────────────────────────────┘
```

### Navigation

Named-route navigation is declared in `main.dart`. Auth-gating is enforced in `onGenerateRoute`.

```
/               → LoginScreen
/register       → RegisterScreen
/home           → HomeScreen
/ride-select    → RideSelectScreen
/ride-confirm   → RideConfirmScreen
/rating         → RatingScreen
/inbox          → InboxScreen
/trips          → TripsScreen
/payment        → PaymentScreen
/profile        → ProfileScreen
```

---

## File Structure

```
lib/
  main.dart
  theme/
    app_theme.dart
  models/
    user.dart
    ride_option.dart
    trip.dart
    notification_model.dart
    payment_card.dart
    mock_data.dart
  providers/
    auth_provider.dart
    ride_provider.dart
    notification_provider.dart
    payment_provider.dart
  screens/
    auth/
      login_screen.dart
      register_screen.dart
    home/
      home_screen.dart
    ride/
      ride_select_screen.dart
      ride_confirm_screen.dart
      rating_screen.dart
    inbox/
      inbox_screen.dart
    trips/
      trips_screen.dart
    payment/
      payment_screen.dart
    profile/
      profile_screen.dart
  widgets/
    bottom_nav_bar.dart
    map_illustration.dart
    toast_overlay.dart
    promo_banner.dart
    ride_option_card.dart
    trip_card.dart
    notification_tile.dart
    payment_card_tile.dart
    safety_features_grid.dart
```

---

## Components and Interfaces

### AppTheme (`lib/theme/app_theme.dart`)

```dart
class AppTheme {
  static const Color scaffoldBg    = Color(0xFF111111);
  static const Color surfaceColor  = Color(0xFF1A1A1A);
  static const Color accentBlue    = Color(0xFF276EF1);
  static const Color accentPurple  = Color(0xFF7B3FF2);
  static const Color textPrimary   = Colors.white;
  static const Color textSecondary = Color(0xFF888888);
  static const Color textTertiary  = Color(0xFF666666);
  static const Color textDisabled  = Color(0xFF444444);
  static const Color readNotifBg   = Color(0xFF161616);
  static const Color borderColor   = Color(0xFF2A2A2A);
  static const Color borderDark    = Color(0xFF1E1E1E);

  static const double radiusSm = 12.0;
  static const double radiusMd = 16.0;
  static const double radiusLg = 20.0;
  static const double radiusXl = 24.0;

  static const TextStyle headingLarge   = TextStyle(fontSize: 32, fontWeight: FontWeight.bold,   color: Colors.white);
  static const TextStyle headingMedium  = TextStyle(fontSize: 24, fontWeight: FontWeight.bold,   color: Colors.white);
  static const TextStyle headingSmall   = TextStyle(fontSize: 20, fontWeight: FontWeight.bold,   color: Colors.white);
  static const TextStyle bodyRegular    = TextStyle(fontSize: 14, fontWeight: FontWeight.normal, color: Colors.white);
  static const TextStyle bodySmall      = TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: Color(0xFF888888));
  static const TextStyle labelUppercase = TextStyle(fontSize: 11, fontWeight: FontWeight.w600,   color: Color(0xFF888888), letterSpacing: 0.8);

  static ThemeData get dark => ThemeData( ... );
}
```

### Providers

#### AuthProvider
```dart
class AuthProvider extends ChangeNotifier {
  AppUser? get currentUser;
  bool     get isLoading;
  String?  get error;
  bool     get isAuthenticated;
  Future<void> login(String email, String password);
  Future<void> register(String name, String email, String phone, String password);
  void logout();
}
```

#### RideProvider
```dart
enum BookingStage { matching, found, arriving }
class RideProvider extends ChangeNotifier {
  String?      get destination;
  RideOption?  get selectedOption;
  BookingStage get stage;
  void setDestination(String d);
  void selectOption(RideOption r);
  void confirmBooking();
  void reset();
}
```

#### NotificationProvider
```dart
enum NotifFilter { all, rides, promos, payments }
class NotificationProvider extends ChangeNotifier {
  int get unreadCount;
  NotifFilter get activeFilter;
  List<AppNotification> get filteredNotifications;
  void markAllRead();
  void setFilter(NotifFilter f);
}
```

#### PaymentProvider
```dart
class PaymentProvider extends ChangeNotifier {
  List<PaymentCard> get cards;
  String get walletBalance;
  void setPrimary(String id);
  void addCard(PaymentCard card);
}
```

---

## Mock Data

All mock data lives in `lib/models/mock_data.dart`:

- **rideOptions**: SwiftX, SwiftXL, Lux Black, Moto
- **trips**: 5 trips (4 completed, 1 cancelled)
- **notifications**: 7 items (3 unread, 4 read)
- **cards**: Visa 4242 (primary), Mastercard 8831

---

## State Transitions

```
BookingStage:  matching ──1.8s──> found ──(3.5s total)──> arriving
RatingState:   idle ──tap star──> rated ──submit──> submitted ──1.5s──> /home
AuthState:     unauthenticated ──login/register──> authenticated ──logout──> unauthenticated
```

---

## Design Tokens

| Token | Value |
|-------|-------|
| scaffoldBg | #111111 |
| surfaceColor | #1A1A1A |
| accentBlue | #276EF1 |
| accentPurple | #7B3FF2 |
| textSecondary | #888888 |
| borderColor | #2A2A2A |
| readNotifBg | #161616 |
| radiusMd | 16 dp |
| radiusXl | 24 dp |
