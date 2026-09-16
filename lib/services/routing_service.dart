import 'api_client.dart';
import 'geocoding_service.dart';

/// A road route returned by the backend's `GET /routing/route`
/// (Stadia-backed; the backend rejects non-India coordinates with 422).
class RouteEstimate {
  final double distanceMeters;
  final double durationSeconds;

  /// Ordered polyline points.
  final List<GeoPoint> geometry;

  const RouteEstimate({
    required this.distanceMeters,
    required this.durationSeconds,
    required this.geometry,
  });

  double get distanceKm => distanceMeters / 1000.0;

  int get durationMinutes {
    final minutes = (durationSeconds / 60).round();
    return minutes < 1 ? 1 : minutes;
  }

  /// `{"distanceMeters":…, "durationSeconds":…, "geometry":[[lng,lat],…]}`
  /// (the backend returns Stadia's `extract_route_details` shape).
  static RouteEstimate? fromJson(Map<String, dynamic> json) {
    final distance = (json['distanceMeters'] as num?)?.toDouble();
    final duration = (json['durationSeconds'] as num?)?.toDouble();
    final rawGeometry = json['geometry'];

    final points = <GeoPoint>[];
    if (rawGeometry is List) {
      for (final entry in rawGeometry) {
        if (entry is List && entry.length >= 2) {
          final lng = (entry[0] as num?)?.toDouble();
          final lat = (entry[1] as num?)?.toDouble();
          if (lat != null && lng != null) points.add(GeoPoint(lat, lng));
        }
      }
    }

    if (distance == null || duration == null || points.length < 2) return null;
    return RouteEstimate(
      distanceMeters: distance,
      durationSeconds: duration,
      geometry: points,
    );
  }
}

/// Road routing against the existing backend. The backend owns the upstream
/// provider and its API key — the client never talks to Stadia directly.
class RoutingService {
  RoutingService._();

  static final ApiClient _api = ApiClient.instance;

  /// `GET /routing/route?from_lat&from_lng&to_lat&to_lng&traffic`
  /// Returns null when the backend reports no drivable route.
  static Future<RouteEstimate?> route({
    required GeoPoint from,
    required GeoPoint to,
    bool traffic = false,
  }) async {
    try {
      final json = await _api.getJson(
        '/routing/route',
        queryParameters: {
          'from_lat': from.lat.toString(),
          'from_lng': from.lng.toString(),
          'to_lat': to.lat.toString(),
          'to_lng': to.lng.toString(),
          'traffic': traffic.toString(),
        },
      );
      if (json is! Map<String, dynamic>) return null;
      return RouteEstimate.fromJson(json);
    } on ApiException {
      return null;
    }
  }
}
