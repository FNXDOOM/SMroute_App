import 'ride_option.dart';

/// Static ride catalogue shown on the ride-select screen.
/// (Trip history, notifications, wallet and cards all come from the backend —
/// no mock fallbacks, so fake data is never presented as real.)
class MockData {
  MockData._();

  static final List<RideOption> rideOptions = [
    RideOption(
      id: 'swift-x',
      name: 'SwiftX',
      description: 'Affordable, everyday rides',
      eta: '3 min',
      priceRange: '\$12–15',
      seats: 4,
      iconEmoji: '🚗',
    ),
    RideOption(
      id: 'swift-xl',
      name: 'SwiftXL',
      description: 'Extra space for groups',
      eta: '6 min',
      priceRange: '\$18–22',
      seats: 6,
      iconEmoji: '🚙',
    ),
    RideOption(
      id: 'swift-lux',
      name: 'Lux Black',
      description: 'Premium cars, top-rated drivers',
      eta: '8 min',
      priceRange: '\$32–40',
      seats: 4,
      iconEmoji: '🖤',
    ),
    RideOption(
      id: 'swift-moto',
      name: 'Moto',
      description: 'Fast and affordable',
      eta: '2 min',
      priceRange: '\$6–9',
      seats: 1,
      iconEmoji: '🏍️',
    ),
  ];
}
