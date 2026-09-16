import 'ride_option.dart';

/// Static ride catalogue — the website's `RIDE_TIERS` (name, description, ETA,
/// seats, price range). These are presentation values only: the backend's
/// server-side fare table (backend/services/razorpay_service.py RIDE_FARES)
/// resolves the real amount from the option ID, so the client can never invent
/// a price. Everything else in the app (trips, notifications, payments) is
/// real backend data — no mock fallbacks.
class MockData {
  MockData._();

  static final List<RideOption> rideOptions = [
    RideOption(
      id: 'swift-x',
      name: 'SwiftX',
      description: 'Affordable, everyday rides',
      eta: '3 min',
      priceRange: '₹12–15',
      seats: 4,
    ),
    RideOption(
      id: 'swift-xl',
      name: 'SwiftXL',
      description: 'Extra space for groups',
      eta: '6 min',
      priceRange: '₹18–22',
      seats: 6,
    ),
    RideOption(
      id: 'swift-lux',
      name: 'Lux Black',
      description: 'Premium cars, top-rated drivers',
      eta: '8 min',
      priceRange: '₹32–40',
      seats: 4,
    ),
    RideOption(
      id: 'swift-moto',
      name: 'Moto',
      description: 'Fast and affordable',
      eta: '2 min',
      priceRange: '₹6–9',
      seats: 1,
    ),
  ];
}
