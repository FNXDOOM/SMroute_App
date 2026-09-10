class GeoPoint {
  final double lat;
  final double lng;

  const GeoPoint(this.lat, this.lng);
}

class LocationService {
  LocationService._();

  /// Matches the "San Francisco, CA" label shown in the UI.
  static const GeoPoint defaultPickup = GeoPoint(37.7749, -122.4194);
  static const Map<String, GeoPoint> _knownPlaces = {
    'home': GeoPoint(37.7758, -122.4182), // 142 Maple Drive (demo)
    'work': GeoPoint(37.7936, -122.3950), // 1 Market St Suite 300
    'gym': GeoPoint(37.7831, -122.4089), // FitLife 90 Howard St
    'fitlife 90 howard st': GeoPoint(37.7831, -122.4089),
    '1 market st suite 300': GeoPoint(37.7936, -122.3950),
    '142 maple drive': GeoPoint(37.7758, -122.4182),
    'sfo airport': GeoPoint(37.6213, -122.3790),
    'whole foods': GeoPoint(37.7710, -122.4220),
    'caltrain station': GeoPoint(37.7764, -122.3943),
  };

  /// Resolves a free-text destination to coordinates.
  ///
  /// Known demo places return fixed points; anything else is a deterministic
  /// pseudo-geocode around downtown SF so repeated inputs are stable.
  /// This is a placeholder until real geocoding is integrated.
  static GeoPoint geocode(String input) {
    final normalized = input.trim().toLowerCase();
    if (_knownPlaces.containsKey(normalized)) {
      return _knownPlaces[normalized]!;
    }

    var hash = normalized.hashCode;
    if (hash < 0) hash = -hash;
    // ±0.04° ≈ ±4km — stays inside the metro area shown on the map.
    final latOffset = ((hash % 1000) / 1000.0 - 0.5) * 0.08;
    final lngOffset = (((hash ~/ 1000) % 1000) / 1000.0 - 0.5) * 0.08;
    return GeoPoint(
      defaultPickup.lat + latOffset,
      defaultPickup.lng + lngOffset,
    );
  }
}
