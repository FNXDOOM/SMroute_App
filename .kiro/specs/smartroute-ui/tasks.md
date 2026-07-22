# Implementation Plan: SmartRoute UI

## Overview

Implement the full SmartRoute Flutter ride-hailing UI across 11 phases: foundation and theme, data models and mock data, state providers, authentication screens, home screen, ride flow (select + confirm), rating screen, inbox, trip history, payment screen, and profile screen — followed by final navigation wiring.

## Tasks

- [ ] 1. Configure pubspec and project foundation
  - Add `provider: ^6.1.2` under `dependencies` in `pubspec.yaml`; retain all existing entries
  - Create the directory scaffold: `lib/theme/`, `lib/models/`, `lib/providers/`, `lib/screens/auth/`, `lib/screens/home/`, `lib/screens/ride/`, `lib/screens/inbox/`, `lib/screens/trips/`, `lib/screens/payment/`, `lib/screens/profile/`, `lib/widgets/`
  - _Requirements: 18.1, 18.2_

- [ ] 2. Implement AppTheme
  - Create `lib/theme/app_theme.dart` with all color constants, border-radius constants, `TextStyle` presets, and the `AppTheme.dark` `ThemeData` getter
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5_

- [ ] 3. Implement data models and mock data
  - [ ] 3.1 Create `lib/models/user.dart` — `AppUser` with `name`, `email`, `phone`, `firstName` getter
    - _Requirements: 2.1_
  - [ ] 3.2 Create `lib/models/ride_option.dart` — `RideOption` with all fields; throw `ArgumentError` when `seats < 1`
    - _Requirements: 2.2, 2.6_
  - [ ] 3.3 Create `lib/models/trip.dart` — `Trip` + `TripStatus` enum
    - _Requirements: 2.3_
  - [ ] 3.4 Create `lib/models/notification_model.dart` — `AppNotification` + `NotificationType` enum
    - _Requirements: 2.4_
  - [ ] 3.5 Create `lib/models/payment_card.dart` — `PaymentCard` with all fields
    - _Requirements: 2.5_
  - [ ] 3.6 Create `lib/models/mock_data.dart` — static `MockData` class with all lists (4 ride options, 5 trips, 7 notifications, 2 cards)
    - _Requirements: 2.1–2.5_

- [ ] 4. Implement state providers
  - [ ] 4.1 Create `lib/providers/auth_provider.dart` — `AuthProvider` with 1-second mock delay, empty-field error
    - _Requirements: 3.1, 3.2, 3.3_
  - [ ] 4.2 Create `lib/providers/ride_provider.dart` — `RideProvider` with `BookingStage` enum, timer-based stage transitions, dispose cleanup
    - _Requirements: 3.4, 3.5_
  - [ ] 4.3 Create `lib/providers/notification_provider.dart` — `NotificationProvider` with filter, markAllRead
    - _Requirements: 3.6, 3.7_
  - [ ] 4.4 Create `lib/providers/payment_provider.dart` — `PaymentProvider` with setPrimary, addCard
    - _Requirements: 3.8, 3.9_

- [ ] 5. Wire up main.dart with MultiProvider and named routes
  - Replace `main.dart`: configure `MaterialApp` with `AppTheme.dark`, register all four providers in `MultiProvider`, define all 10 named routes, implement `onGenerateRoute` auth guard
  - _Requirements: 4.1, 4.2, 3.10_

- [ ] 6. Implement MapWidget
  - Create `lib/widgets/map_illustration.dart` — `MapWidget` as `CustomPainter` with dark background, grid lines, road rectangles, optional blue route polyline
  - _Requirements: 8.1, 8.2, 8.3, 8.4_

- [ ] 7. Implement shared widgets
  - [ ] 7.1 Create `lib/widgets/bottom_nav_bar.dart` — four tabs, active=white, badge on Inbox
    - _Requirements: 16.1–16.4_
  - [ ] 7.2 Create `lib/widgets/promo_banner.dart` — gradient blue-to-purple card
    - _Requirements: 7.4_
  - [ ] 7.3 Create `lib/widgets/ride_option_card.dart` — selectable card with white border when selected
    - _Requirements: 9.5, 9.6_
  - [ ] 7.4 Create `lib/widgets/trip_card.dart` — trip summary with status badge, fare, route dots, links
    - _Requirements: 13.4_
  - [ ] 7.5 Create `lib/widgets/notification_tile.dart` — colored icon circle, read/unread styling
    - _Requirements: 12.4_
  - [ ] 7.6 Create `lib/widgets/payment_card_tile.dart` — brand icon, last4, expiry, primary badge
    - _Requirements: 14.2_
  - [ ] 7.7 Create `lib/widgets/safety_features_grid.dart` — 3-column grid with Share trip, Emergency, Track live
    - _Requirements: 10.4_
  - [ ] 7.8 Create `lib/widgets/toast_overlay.dart` — stacked toasts, auto-dismiss 4s, manual dismiss
    - _Requirements: 17.1–17.3_

- [ ] 8. Implement auth screens
  - [ ] 8.1 Create `lib/screens/auth/login_screen.dart`
    - _Requirements: 5.1–5.6_
  - [ ] 8.2 Create `lib/screens/auth/register_screen.dart`
    - _Requirements: 6.1–6.4_

- [ ] 9. Implement Home screen
  - Create `lib/screens/home/home_screen.dart` — greeting, bell badge, avatar, promo banner, push banner, MapWidget, search input, Find a ride button, recent places, BottomNavBar
  - _Requirements: 7.1–7.10_

- [ ] 10. Implement Ride Select screen
  - Create `lib/screens/ride/ride_select_screen.dart` — MapWidget with route, back button, route info bar, 4 RideOptionCards, Book button
  - _Requirements: 9.1–9.6_

- [ ] 11. Implement Ride Confirm screen
  - Create `lib/screens/ride/ride_confirm_screen.dart` — matching spinner, driver card, safety grid, Done button, stage transitions
  - _Requirements: 10.1–10.6_

- [ ] 12. Implement Rating screen
  - Create `lib/screens/ride/rating_screen.dart` — 5 stars, tag chips, comment field, submit button, success state
  - _Requirements: 11.1–11.4_

- [ ] 13. Implement Inbox screen
  - Create `lib/screens/inbox/inbox_screen.dart` — filter tabs, notification list, mark all read
  - _Requirements: 12.1–12.4_

- [ ] 14. Implement Trips screen
  - Create `lib/screens/trips/trips_screen.dart` — Past/Scheduled tabs, TripCard list, empty state
  - _Requirements: 13.1–13.3_

- [ ] 15. Implement Payment screen
  - Create `lib/screens/payment/payment_screen.dart` — wallet card, card tiles, add card sheet, promo input, transactions
  - _Requirements: 14.1–14.5_

- [ ] 16. Implement Profile screen
  - Create `lib/screens/profile/profile_screen.dart` — avatar, stats, contact info, menu, sign out sheet
  - _Requirements: 15.1–15.5_

- [ ] 17. Final navigation wiring and integration
  - Verify full navigation flow in `main.dart`: stack-clearing pushes, argument passing, BottomNavBar replacements
  - _Requirements: 4.1–4.9_

## Task Dependency Graph

```json
{
  "waves": [
    ["1"],
    ["2"],
    ["3.1", "3.2", "3.3", "3.4", "3.5"],
    ["3.6"],
    ["4.1", "4.2", "4.3", "4.4"],
    ["5"],
    ["6", "7.1", "7.2", "7.3", "7.4", "7.5", "7.6", "7.7", "7.8"],
    ["8.1", "8.2", "9", "10", "11", "12", "13", "14", "15", "16"],
    ["17"]
  ]
}
```
