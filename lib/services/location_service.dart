import 'package:geolocator/geolocator.dart';

import 'api_client.dart';
import 'geocoding_service.dart';

/// Outcome of a GPS lookup — either a point (optionally with a resolved
/// label) or a user-facing reason it failed.
class LocationResult {
  final GeoPoint? point;
  final String? label;
  final String? error;

  const LocationResult.success(this.point, this.label) : error = null;
  const LocationResult.failure(this.error) : point = null, label = null;

  bool get ok => point != null;
}

/// Device location + reverse geocoding against the existing backend.
///
/// Mirrors the website's `navigator.geolocation` flow: request permission,
/// read the position, then reverse-geocode it through the backend's
/// India-only `GET /geocode/reverse` so labels and service-area checks stay
/// server-authoritative. Nothing is fabricated when GPS is unavailable —
/// callers fall back to the Bengaluru default service point.
class LocationService {
  LocationService._();

  static final ApiClient _api = ApiClient.instance;

  /// Bengaluru city centre — the backend service area is India-only.
  static const GeoPoint fallbackPoint = GeoPoint(12.9716, 77.5946);

  /// Requests permission if needed and returns the current position.
  /// Never throws — failures come back as [LocationResult.failure].
  static Future<LocationResult> currentPosition({
    bool reverseGeocode = true,
  }) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationResult.failure('Location services are turned off.');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        return const LocationResult.failure('Location permission was denied.');
      }
      if (permission == LocationPermission.deniedForever) {
        return const LocationResult.failure(
          'Location permission is blocked. Enable it in system settings.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );

      final point = GeoPoint(position.latitude, position.longitude);
      if (!reverseGeocode) return LocationResult.success(point, null);

      final label = await reverseLabel(point);
      return LocationResult.success(point, label);
    } catch (_) {
      return const LocationResult.failure(
        'Unable to determine your current location.',
      );
    }
  }

  /// `GET /geocode/reverse` — server-side label for a coordinate. Returns null
  /// when the point is outside the backend's India service area or upstream
  /// geocoding fails.
  static Future<String?> reverseLabel(GeoPoint point) async {
    final suggestion = await reverse(point);
    return suggestion?.label;
  }

  /// Full reverse-geocode result (coordinates snapped by the backend + label).
  static Future<PlaceSuggestion?> reverse(GeoPoint point) async {
    try {
      final json = await _api.getJson(
        '/geocode/reverse',
        queryParameters: {
          'lat': point.lat.toString(),
          'lng': point.lng.toString(),
        },
      );
      if (json is! Map<String, dynamic>) return null;
      return PlaceSuggestion.fromJson(json);
    } on ApiException {
      return null;
    }
  }

  /// `GET /routing/nearest-road` — snaps a tapped map point to a drivable road
  /// before it becomes a pickup (same flow as the website's "Choose on map").
  static Future<GeoPoint?> nearestRoad(GeoPoint point) async {
    try {
      final json = await _api.getJson(
        '/routing/nearest-road',
        queryParameters: {
          'lat': point.lat.toString(),
          'lng': point.lng.toString(),
        },
      );
      if (json is Map<String, dynamic>) {
        final lat = (json['lat'] as num?)?.toDouble();
        final lng = (json['lng'] as num?)?.toDouble();
        if (lat != null && lng != null) return GeoPoint(lat, lng);
      }
      return null;
    } on ApiException {
      return null;
    }
  }
}
