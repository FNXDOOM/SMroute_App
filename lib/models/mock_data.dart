import 'notification_model.dart';
import 'payment_card.dart';
import 'ride_option.dart';
import 'trip.dart';

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

  static final List<Trip> trips = const [
    Trip(
      id: 't1',
      date: 'Today, 2:15 PM',
      from: 'Home',
      to: '1 Market St',
      fare: '\$14.20',
      type: 'SwiftX',
      status: TripStatus.completed,
    ),
    Trip(
      id: 't2',
      date: 'Mon, Jul 18',
      from: 'FitLife Gym',
      to: 'Home',
      fare: '\$9.50',
      type: 'SwiftX',
      status: TripStatus.completed,
    ),
    Trip(
      id: 't3',
      date: 'Fri, Jul 15',
      from: 'SFO Airport',
      to: 'Work',
      fare: '\$38.75',
      type: 'Lux Black',
      status: TripStatus.completed,
    ),
    Trip(
      id: 't4',
      date: 'Wed, Jul 13',
      from: 'Work',
      to: 'Whole Foods',
      fare: '\$7.80',
      type: 'Moto',
      status: TripStatus.completed,
    ),
    Trip(
      id: 't5',
      date: 'Tue, Jul 12',
      from: 'Home',
      to: 'Caltrain Station',
      fare: '\$11.40',
      type: 'SwiftX',
      status: TripStatus.cancelled,
    ),
  ];

  static List<AppNotification> get notifications => [
        AppNotification(
          id: 'n1',
          type: NotificationType.ride,
          title: 'Your ride is complete',
          body: 'You arrived at 1 Market St. Fare: \$14.20',
          time: '2 min ago',
          read: false,
          icon: '🚗',
        ),
        AppNotification(
          id: 'n2',
          type: NotificationType.promo,
          title: '20% off your next 3 rides',
          body: 'Use code SWIFT20 before it expires in 2 days',
          time: '1 hr ago',
          read: false,
          icon: '🎉',
        ),
        AppNotification(
          id: 'n3',
          type: NotificationType.payment,
          title: 'Payment confirmed',
          body: '\$14.20 charged to Visa ending in 4242',
          time: '1 hr ago',
          read: false,
          icon: '💳',
        ),
        AppNotification(
          id: 'n4',
          type: NotificationType.ride,
          title: 'Driver is 2 minutes away',
          body: 'Marcus T. is approaching in a silver Camry',
          time: 'Yesterday',
          read: true,
          icon: '📍',
        ),
        AppNotification(
          id: 'n5',
          type: NotificationType.system,
          title: 'New feature: Schedule rides',
          body: 'Book your rides up to 7 days in advance',
          time: 'Yesterday',
          read: true,
          icon: '🗓️',
        ),
        AppNotification(
          id: 'n6',
          type: NotificationType.promo,
          title: 'Refer a friend, earn \$10',
          body: 'Share your code ALEXR10 and get rewarded',
          time: '3 days ago',
          read: true,
          icon: '👥',
        ),
        AppNotification(
          id: 'n7',
          type: NotificationType.payment,
          title: 'Receipt for your trip',
          body: 'Full summary of your Tuesday ride to Gym',
          time: '4 days ago',
          read: true,
          icon: '🧾',
        ),
      ];

  static List<PaymentCard> get cards => [
        PaymentCard(
          id: 'c1',
          brand: 'Visa',
          last4: '4242',
          expiry: '12/26',
          isPrimary: true,
        ),
        PaymentCard(
          id: 'c2',
          brand: 'Mastercard',
          last4: '8831',
          expiry: '03/25',
          isPrimary: false,
        ),
      ];
}
