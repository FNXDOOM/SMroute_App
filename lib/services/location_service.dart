class GeoPoint {
  final double lat;
  final double lng;

  const GeoPoint(this.lat, this.lng);
}

class LocationService {
  LocationService._();

  static const GeoPoint defaultPickup = GeoPoint(12.9716, 77.5946);
  static final Map<String, GeoPoint> _knownPlaces = {
    'home': const GeoPoint(12.9718, 77.5949),
    'work': const GeoPoint(12.9752, 77.5983),
    'gym': const GeoPoint(12.9684, 77.5912),
    'fitlife 90 howard st': const GeoPoint(12.9692, 77.5961),
    '1 market st suite 300': const GeoPoint(12.9729, 77.6021),
    '142 maple drive': const GeoPoint(12.9781, 77.5892),
    'sfo airport': const GeoPoint(12.9950, 77.7066),
    'whole foods': const GeoPoint(12.9640, 77.6091),
    'caltrain station': const GeoPoint(12.9850, 77.6004),
  };

  static GeoPoint geocode(String input) {
    final normalized = input.trim().toLowerCase();
    if (_knownPlaces.containsKey(normalized)) {
      return _knownPlaces[normalized]!;
    }

    var hash = normalized.hashCode;
    if (hash < 0) hash = -hash;
    final latOffset = ((hash % 1000) / 1000.0 - 0.5) * 0.08;
    final lngOffset = (((hash ~/ 1000) % 1000) / 1000.0 - 0.5) * 0.08;
    return GeoPoint(
      defaultPickup.lat + latOffset,
      defaultPickup.lng + lngOffset,
    );
  }
}
