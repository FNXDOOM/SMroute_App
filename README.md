# SmartRoute 🚗

A full-featured ride-hailing app UI built with Flutter, inspired by Uber's dark design language. Implements the complete user journey from login through ride booking, rating, notifications, trip history, payment management, and profile.

**Backend status:** Auth, ride requests, ride vehicle assignment, live vehicle position, and notifications (including real-time push over WebSocket) are wired up to a real FastAPI backend (`finalyr_project` — SmartRouteAI), including one backend endpoint (`GET /rides/{id}/vehicle`) added specifically to support this app. Ride tiers and payments are still mock/static — see [`BACKEND_INTEGRATION_PLAN.md`](./BACKEND_INTEGRATION_PLAN.md) for the full breakdown of what's real, what's mock, what's broken, and what needs a backend change.

---

## Screenshots

| Login | Home | Ride Select |
|-------|------|-------------|
| Dark login screen with SmartRoute branding | Map illustration, search bar, recent places | 4 ride options with price & ETA |

| Ride Confirm | Rating | Profile |
|---|---|---|
| Driver card with live stage transitions | 5-star rating with tag chips | Stats, menu, sign-out sheet |

---

## Features

- **Authentication** — Login & Register against the real backend (JWT, session restore) ✅ live
- **Home Screen** — Time-aware greeting, live notification badge, promo banner, push permission banner, map illustration, destination search, recent places
- **Ride Selection** — 4 ride tiers (SwiftX, SwiftXL, Lux Black, Moto) with price ranges and ETAs — mock pricing (backend has no ride-tier/pricing endpoint, this is intentional, see plan doc)
- **Ride Booking** — Posts a real ride request to the backend and loads real ride history ✅ live
- **Ride Confirmation** — Animated stage transitions: Matching → Driver Found → Arriving; shows the real assigned vehicle's license plate, status, and live GPS position once the backend assigns one ✅ live (driver's personal name/rating is a generic placeholder — backend has no driver-identity field)
- **Post-Ride Rating** — 5-star interactive rating, tag chips, optional comment, success state
- **Inbox** — Real backend notifications with live WebSocket push, filterable (All / Rides / Promos / Payments), mark-all-read ✅ live
- **Trip History** — Real ride history from the backend, status badges, pull-to-refresh ✅ live
- **Payment** — Wallet balance, payment cards, add card bottom sheet, promo codes, transaction history — backend has no payments router yet, falls back to mock data
- **Profile** — User stats, contact info, settings menu with notifications toggle, sign-out confirmation
- **Toast Overlay** — Auto-dismissing stacked toasts at top-center
- **Bottom Navigation** — 4-tab nav with unread badge on Inbox tab

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| UI Framework | Flutter 3.x (Material 3, dark theme) |
| State Management | `provider ^6.1.2` (ChangeNotifier) |
| Navigation | Named routes with auth guard |
| Maps | Custom `CustomPainter` illustration (no SDK needed) |
| Backend | FastAPI (`finalyr_project`) over HTTP + WebSocket, JWT auth |
| Networking | `http` package via `ApiClient` (`lib/services/api_client.dart`) |
| Local storage | `shared_preferences` for JWT persistence |
| Data | Auth / rides / vehicle assignment / live tracking / notifications are live API + WebSocket calls; ride pricing and payments are still mock/static (see plan doc) |

---

## Prerequisites

Before running the app, make sure you have the following installed:

1. **Flutter SDK** (3.0 or newer)
   - Download: https://docs.flutter.dev/get-started/install
   - After installing, run `flutter doctor` to verify your setup

2. **Android Studio** or **VS Code** with the Flutter/Dart extensions

3. **An Android emulator or physical device**
   - Android: Open Android Studio → Device Manager → Create a virtual device
   - Or connect a real Android/iOS device via USB with USB debugging enabled

4. **The backend running** (for auth / rides / notifications to work)
   - See `finalyr_project/README.md` for setup — `uvicorn backend.main:app --reload`, default at `http://localhost:8000`
   - The app defaults to `http://127.0.0.1:8000`. Override with:
     ```bash
     flutter run --dart-define=SMARTROUTE_API_BASE_URL=http://<your-host>:8000
     ```
   - On an Android emulator, `127.0.0.1` refers to the emulator itself, not your host machine — use `http://10.0.2.2:8000` instead when running on the emulator.

---

## How to Run

### Step 1 — Clone / open the project

Open a terminal in the project folder:

```
c:\Users\gudiy\OneDrive\Desktop\flutter workspace\finalyr_app
```

Or open it in VS Code:
```
code "c:\Users\gudiy\OneDrive\Desktop\flutter workspace\finalyr_app"
```

### Step 2 — Install dependencies

```bash
flutter pub get
```

### Step 3 — Check connected devices

```bash
flutter devices
```

You should see at least one device listed (emulator or physical phone).

### Step 4 — Run the app

```bash
flutter run
```

To run on a specific device (replace `<device-id>` with the id from step 3):

```bash
flutter run -d <device-id>
```

**Common device IDs:**
- Android emulator: `emulator-5554`
- Chrome (web): `chrome`
- Windows desktop: `windows`

### Step 5 — Try the app

1. On the **Login** screen, enter any email and password (e.g. `test@test.com` / `password`) and tap **Continue**
2. You land on **Home** — tap a recent place or type a destination and tap **Find a ride →**
3. Pick a ride tier on the **Ride Select** screen and tap **Book**
4. Watch the **Ride Confirm** screen animate through matching → found → arriving stages automatically
5. Tap **Done** → rate your driver on the **Rating** screen
6. Explore **Inbox**, **Trips**, **Payment**, and **Profile** from the bottom nav or the bell/avatar buttons

---

## Build Commands

### Debug APK (Android)

```bash
flutter build apk --debug
```

Output: `build/app/outputs/flutter-apk/app-debug.apk`

### Release APK (Android)

```bash
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

### Install directly on connected device

```bash
flutter install
```

---

## Project Structure

```
lib/
├── main.dart                    # App entry point, MultiProvider, named routes
├── theme/
│   └── app_theme.dart           # All design tokens, TextStyles, ThemeData
├── models/
│   ├── user.dart                # AppUser model
│   ├── ride_option.dart         # RideOption model
│   ├── assigned_vehicle.dart    # AssignedVehicle model — GET /rides/{id}/vehicle + /tracking/ws
│   ├── trip.dart                # Trip model + TripStatus enum
│   ├── notification_model.dart  # AppNotification + NotificationType enum
│   ├── payment_card.dart        # PaymentCard model
│   └── mock_data.dart           # All static mock data
├── providers/
│   ├── auth_provider.dart       # Login / register / logout — real backend calls
│   ├── ride_provider.dart       # Ride booking + history + vehicle assignment polling + live tracking — real backend calls
│   ├── notification_provider.dart # List + mark-all-read + live WebSocket — real backend calls
│   └── payment_provider.dart   # Cards + wallet — calls backend, falls back to mock (no payments router yet)
├── services/
│   ├── api_client.dart          # Shared HTTP client — base URL, JWT header, error handling
│   ├── firebase_auth_service.dart
│   └── location_service.dart
├── screens/
│   ├── auth/
│   │   ├── login_screen.dart
│   │   └── register_screen.dart
│   ├── home/
│   │   └── home_screen.dart
│   ├── ride/
│   │   ├── ride_select_screen.dart
│   │   ├── ride_confirm_screen.dart
│   │   └── rating_screen.dart
│   ├── inbox/
│   │   └── inbox_screen.dart
│   ├── trips/
│   │   └── trips_screen.dart
│   ├── payment/
│   │   └── payment_screen.dart
│   └── profile/
│       └── profile_screen.dart
└── widgets/
    ├── bottom_nav_bar.dart
    ├── map_illustration.dart
    ├── toast_overlay.dart
    ├── promo_banner.dart
    ├── ride_option_card.dart
    ├── trip_card.dart
    ├── notification_tile.dart
    ├── payment_card_tile.dart
    └── safety_features_grid.dart
```

---

## Design System

| Token | Value |
|-------|-------|
| Scaffold background | `#111111` |
| Card / surface | `#1A1A1A` |
| Accent blue | `#276EF1` |
| Accent purple | `#7B3FF2` |
| Text secondary | `#888888` |
| Border | `#2A2A2A` |
| Card border radius | 20–24 dp |
| Button border radius | 16 dp |

---

## Backend Integration Status

See [`BACKEND_INTEGRATION_PLAN.md`](./BACKEND_INTEGRATION_PLAN.md) for the running list of:
- bugs found and fixed in the real API integration
- features that are still mock and why
- features that were blocked on a backend change (F2/F3 — now resolved by adding `GET /rides/{id}/vehicle` to `finalyr_project`) and the exact diff applied

---

## Troubleshooting

**`flutter: command not found`**
→ Add the Flutter `bin` directory to your PATH. See https://docs.flutter.dev/get-started/install/windows

**`No devices found`**
→ Start an Android emulator in Android Studio (Device Manager → ▶ Play button) then re-run `flutter devices`

**`Gradle build failed`**
→ Run `flutter clean` then `flutter pub get` then try again

**App shows white screen on launch**
→ Run `flutter run --verbose` to see detailed logs

---

## License

This project is for educational / portfolio use.
