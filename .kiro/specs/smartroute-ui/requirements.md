# Requirements Document

## Introduction

SmartRoute is a Flutter-based ride-hailing app UI that faithfully implements a dark Uber-like design prototype. The app covers the complete user journey: authentication (login / register), home with destination search, ride selection, real-time booking confirmation with driver card, post-ride rating, inbox / notifications, trip history, payment management, and a user profile screen. All data is mock / static; no real backend or maps are used. State is managed with the `provider` package.

---

## Glossary

- **App** / **SmartRoute**: The Flutter application being built.
- **AuthProvider**: `ChangeNotifier` that holds the authenticated `AppUser` and exposes login / logout / register methods.
- **RideProvider**: `ChangeNotifier` that holds the current destination, selected ride option, and booking stage.
- **NotificationProvider**: `ChangeNotifier` that holds the list of `AppNotification` objects and unread count.
- **PaymentProvider**: `ChangeNotifier` that holds wallet balance, payment cards list, and set-primary logic.
- **AppUser**: Data class with `name`, `email`, and `phone` fields.
- **RideOption**: Data class representing a ride tier (id, name, description, ETA, price range, seat count, icon emoji).
- **Trip**: Data class representing a completed or cancelled trip (id, date, from, to, fare, type, status).
- **AppNotification**: Data class for an inbox notification (id, type, title, body, time, read, icon).
- **PaymentCard**: Data class for a saved card (id, brand, last4, expiry, isPrimary).
- **BookingStage**: Enum with values `matching`, `found`, `arriving`.
- **MapWidget**: Custom Flutter widget that renders a dark grid / road illustration instead of a real map.
- **ToastOverlay**: Overlay widget that stacks dismissable toast messages at the top-center of the screen.
- **BottomNavBar**: Shared bottom navigation bar widget with four tabs.
- **AppTheme**: Central class providing `ThemeData`, color constants, and `TextStyle` definitions.

---

## Requirements

### Requirement 1: App Theme and Design System

**User Story:** As a developer, I want a centralized dark-mode theme based on the SmartRoute design tokens, so that every screen is consistent without repeating style definitions.

#### Acceptance Criteria

1. THE App SHALL use a `ThemeData` with `brightness: Brightness.dark` and a scaffold background color of `#111111`.
2. THE AppTheme SHALL define named color constants: `surfaceColor (#1a1a1a)`, `accentBlue (#276EF1)`, `accentPurple (#7B3FF2)`, `textPrimary (white)`, `textSecondary (#888888)`, `textTertiary (#666666)`, `textDisabled (#444444)`, `readNotifBg (#161616)`, `borderColor (#2a2a2a)`.
3. THE AppTheme SHALL define `TextStyle` presets: `headingLarge` (bold, 32 sp), `headingMedium` (bold, 24 sp), `headingSmall` (bold, 20 sp), `bodyRegular` (normal, 14 sp), `bodySmall` (normal, 12 sp), `labelUppercase` (semibold, 11 sp, letter spacing 0.8).
4. THE AppTheme SHALL set global `InputDecorationTheme` with filled background `#1a1a1a`, border radius 12 dp, and no focused underline.
5. THE AppTheme SHALL set global `ElevatedButtonThemeData` matching the primary CTA style: white background, black bold text, border radius 16 dp, height 52 dp.

### Requirement 2: Data Models

**User Story:** As a developer, I want immutable, well-typed Dart model classes for all domain objects, so that providers and screens can rely on a single source of truth.

#### Acceptance Criteria

1. THE `AppUser` model SHALL contain `String name`, `String email`, `String phone` fields and expose a `firstName` getter returning the first word of `name`.
2. THE `RideOption` model SHALL contain `String id`, `String name`, `String description`, `String eta`, `String priceRange`, `int seats`, `String iconEmoji` fields.
3. THE `Trip` model SHALL contain `String id`, `String date`, `String from`, `String to`, `String fare`, `String type`, `TripStatus status` where `TripStatus` is an enum `{completed, cancelled}`.
4. THE `AppNotification` model SHALL contain `String id`, `NotificationType type`, `String title`, `String body`, `String time`, `bool read`, `String icon` where `NotificationType` is an enum `{ride, promo, payment, system}`.
5. THE `PaymentCard` model SHALL contain `String id`, `String brand`, `String last4`, `String expiry`, `bool isPrimary` fields.
6. WHEN a model field violates runtime constraints (e.g., `seats < 1`), THE model constructor SHALL throw an `ArgumentError`.

### Requirement 3: State Management (Providers)

**User Story:** As a developer, I want `ChangeNotifier`-based providers registered at the app root, so that any widget can read or update shared state without prop drilling.

#### Acceptance Criteria

1. THE `AuthProvider` SHALL expose `AppUser? currentUser`, `bool isLoading`, `String? error`, `bool isAuthenticated`, `login()`, `register()`, `logout()`.
2. WHEN `login()` or `register()` is called, THE `AuthProvider` SHALL simulate a 1-second delay then set `currentUser`.
3. IF `login()` or `register()` receives empty fields, THEN THE `AuthProvider` SHALL set an error message without setting `currentUser`.
4. THE `RideProvider` SHALL expose `String? destination`, `RideOption? selectedOption`, `BookingStage stage`, `setDestination()`, `selectOption()`, `confirmBooking()`, `reset()`.
5. WHEN `confirmBooking()` is called, THE `RideProvider` SHALL set `stage = matching`, then after 1.8 s set `stage = found`, then after 3.5 s set `stage = arriving`.
6. THE `NotificationProvider` SHALL expose 7 mock notifications, `unreadCount`, `filteredNotifications`, `markAllRead()`, `setFilter()`, `activeFilter`.
7. WHEN `markAllRead()` is called, THE `NotificationProvider` SHALL set `read = true` on all notifications and `unreadCount` to 0.
8. THE `PaymentProvider` SHALL expose 2 mock cards, `walletBalance`, `setPrimary(id)`, `addCard()`.
9. WHEN `setPrimary(id)` is called, exactly one card SHALL have `isPrimary = true`.
10. THE `MultiProvider` at app root SHALL register all four providers.

### Requirement 4: Navigation and Routing

**User Story:** As a user, I want seamless navigation between all screens, so that I can move through the app without dead ends.

#### Acceptance Criteria

1. THE App SHALL define named routes: `/` (login), `/register`, `/home`, `/ride-select`, `/ride-confirm`, `/rating`, `/inbox`, `/trips`, `/payment`, `/profile`.
2. WHEN `AuthProvider.isAuthenticated` is `false`, THE App SHALL redirect navigation to `/`.
3. WHEN login or registration succeeds, THE App SHALL navigate to `/home` clearing the back-stack.
4. WHEN the user taps "Find a ride →", THE App SHALL navigate to `/ride-select` with the destination string as argument.
5. WHEN the user confirms a ride, THE App SHALL navigate to `/ride-confirm` with the selected `RideOption` as argument.
6. WHEN "Done" is tapped on ride-confirm, THE App SHALL navigate to `/rating`.
7. WHEN rating is submitted, THE App SHALL navigate to `/home` after 1.5 s, clearing the ride flow stack.
8. WHEN back arrow is tapped on secondary screens, THE App SHALL navigate back to `/home`.
9. THE BottomNavBar SHALL use `pushReplacementNamed` to avoid duplicate route stacking.

### Requirement 5: Login Screen

**User Story:** As a returning user, I want to sign in with my email/phone and password.

#### Acceptance Criteria

1. THE LoginScreen SHALL display car-icon logo, "SmartRoute" name, and headline "What's your email or phone?".
2. THE LoginScreen SHALL render an email/phone `TextField` and a password `TextField` (obscured).
3. WHEN "Continue" is tapped with non-empty fields, THE LoginScreen SHALL call `AuthProvider.login()` and show a loading indicator.
4. IF either field is empty, THEN THE LoginScreen SHALL display "Please fill in all fields.".
5. THE LoginScreen SHALL render a ghost "Create account" button navigating to `/register`.
6. THE LoginScreen SHALL display Terms and Privacy Policy links at the bottom.

### Requirement 6: Register Screen

**User Story:** As a new user, I want to create a SmartRoute account.

#### Acceptance Criteria

1. THE RegisterScreen SHALL display four labelled fields: Full name, Email, Phone number, Password.
2. WHEN "Create account" is tapped with all fields filled, THE RegisterScreen SHALL call `AuthProvider.register()`.
3. IF any field is empty, THEN THE RegisterScreen SHALL display "Please fill in all fields.".
4. WHEN the "Sign in" link is tapped, THE RegisterScreen SHALL navigate to `/`.

### Requirement 7: Home Screen

**User Story:** As an authenticated user, I want a rich home screen to quickly book a ride.

#### Acceptance Criteria

1. THE HomeScreen SHALL display a time-sensitive greeting (morning/afternoon/evening + first name).
2. THE HomeScreen SHALL display a bell icon with blue unread badge (hidden when 0, "9+" when >9).
3. THE HomeScreen SHALL display a first-name avatar navigating to `/profile`.
4. THE HomeScreen SHALL display a gradient promo banner (🎉 emoji, "20% off your next 3 rides", "SWIFT20" code).
5. THE HomeScreen SHALL display a push-notification permission banner (dismissable).
6. THE HomeScreen SHALL render the `MapWidget` with location dot and "📍 San Francisco, CA" label.
7. THE HomeScreen SHALL render a white "Where to?" search input card.
8. WHEN the destination input is non-empty, THE HomeScreen SHALL show a "Find a ride →" blue button.
9. THE HomeScreen SHALL list three recent places (Home, Work, Gym).
10. THE HomeScreen SHALL display the `BottomNavBar` with "Home" tab active.

### Requirement 8: Map Widget

**User Story:** As a developer, I want a custom Flutter widget simulating a dark map illustration.

#### Acceptance Criteria

1. THE MapWidget SHALL render a dark background with city-block grid lines.
2. THE MapWidget SHALL paint road surface rectangles.
3. WHEN `showRoute` is `true`, THE MapWidget SHALL draw a blue polyline.
4. THE MapWidget SHALL be a `CustomPainter`-based stateless widget.

### Requirement 9: Ride Select Screen

**User Story:** As a user, I want to compare ride options before booking.

#### Acceptance Criteria

1. THE RideSelectScreen SHALL display `MapWidget(showRoute: true)` at the top.
2. THE RideSelectScreen SHALL display a back button overlay.
3. THE RideSelectScreen SHALL show a route-info bar with destination, distance, and duration.
4. THE RideSelectScreen SHALL render four `RideOptionCard` widgets (SwiftX, SwiftXL, Lux Black, Moto).
5. WHEN a card is tapped, THE selected card SHALL highlight with a white border.
6. THE RideSelectScreen SHALL display a "Book [RideName] · [Price]" CTA button.

### Requirement 10: Ride Confirm Screen

**User Story:** As a user, I want to see booking progression with driver details.

#### Acceptance Criteria

1. WHEN `stage == matching`, THE screen SHALL show a spinner and "Finding your driver".
2. WHEN `stage == found`, THE screen SHALL show a blue status pill and driver card.
3. WHEN `stage == arriving`, THE screen SHALL show a green status pill.
4. THE driver card SHALL show avatar "M", name "Marcus T.", rating 4.98, 1204 trips, 💬/📞 buttons, detail rows, and `SafetyFeaturesGrid`.
5. THE screen SHALL show a "Done" button navigating to `/rating`.
6. Stage timers SHALL be cancelled on widget dispose.

### Requirement 11: Rating Screen

**User Story:** As a user, I want to rate my driver after a ride.

#### Acceptance Criteria

1. THE RatingScreen SHALL render 5 interactive star buttons (yellow when selected).
2. WHEN `stars > 0`, THE screen SHALL reveal tag chips and comment field.
3. WHEN `stars == 0`, THE "Submit rating" button SHALL be disabled.
4. AFTER submit, THE screen SHALL show success state then navigate to `/home` after 1.5 s.

### Requirement 12: Inbox Screen

**User Story:** As a user, I want to view and filter my notifications.

#### Acceptance Criteria

1. THE InboxScreen SHALL display filter tabs: All, Rides, Promos, Payments.
2. THE InboxScreen SHALL show "Mark all read" button only when `unreadCount > 0`.
3. THE InboxScreen SHALL render a `NotificationTile` for each filtered notification.
4. Unread tiles SHALL have blue dot indicator and `#276EF1/20` border.

### Requirement 13: Trip History Screen

**User Story:** As a user, I want to view past trips and scheduled rides.

#### Acceptance Criteria

1. THE TripsScreen SHALL render "Past" and "Scheduled" segment tabs.
2. THE Past tab SHALL show 5 `TripCard` widgets with trip details.
3. THE Scheduled tab SHALL show an empty state with "Schedule a ride" button.

### Requirement 14: Payment Screen

**User Story:** As a user, I want to manage my wallet, cards, and promo codes.

#### Acceptance Criteria

1. THE PaymentScreen SHALL show gradient wallet card with balance and Add/Withdraw buttons.
2. THE PaymentScreen SHALL render `PaymentCardTile` for each card.
3. WHEN "Set primary" is tapped, `PaymentProvider.setPrimary(id)` SHALL be called.
4. THE PaymentScreen SHALL show "Add card" bottom sheet with card fields.
5. THE PaymentScreen SHALL show promo code input and recent transactions.

### Requirement 15: Profile Screen

**User Story:** As a user, I want to view and manage my profile settings.

#### Acceptance Criteria

1. THE ProfileScreen SHALL show avatar, name, rating "4.96", "Verified rider" badge.
2. THE ProfileScreen SHALL show stats grid (Trips 47, Rating 4.96, Since '23).
3. THE ProfileScreen SHALL show settings menu with Payment, Notifications toggle, and other items.
4. THE ProfileScreen SHALL show sign-out confirmation bottom sheet.
5. WHEN sign-out is confirmed, `AuthProvider.logout()` SHALL be called and app SHALL navigate to `/`.

### Requirement 16: Bottom Navigation Bar

**User Story:** As a user, I want a persistent bottom navigation bar.

#### Acceptance Criteria

1. THE `BottomNavBar` SHALL render four tabs: Home, Trips, Inbox, Account.
2. THE active tab SHALL render in white; inactive in `#555555`.
3. THE Inbox tab SHALL show a blue badge with unread count (capped at "9+").
4. THE background SHALL be `#111111` with `#1e1e1e` top border.

### Requirement 17: Toast Overlay

**User Story:** As a user, I want non-intrusive toast messages for ride events.

#### Acceptance Criteria

1. THE `ToastOverlay` SHALL render toasts at top-center, 340 dp wide, stacked with 8 dp gap.
2. EACH toast SHALL auto-dismiss after 4 seconds and support manual ✕ dismiss.
3. THE toast SHALL have dark frosted-glass appearance: `#1c1c1e` background, white/10 border, 16 dp radius.

### Requirement 18: pubspec.yaml Configuration

**User Story:** As a developer, I want pubspec.yaml updated with required dependencies.

#### Acceptance Criteria

1. THE `pubspec.yaml` SHALL include `provider: ^6.1.2` under `dependencies`.
2. THE `pubspec.yaml` SHALL retain all existing entries.
