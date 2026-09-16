import 'dart:async';

import '../services/api_client.dart';

class GeoPoint {
  final double lat;
  final double lng;

  const GeoPoint(this.lat, this.lng);

  /// True when the point is inside the backend's India service area
  /// (mirrors backend/utils/geo.py is_india_location — the backend remains
  /// authoritative and re-validates every ride write).
  bool get isInIndiaServiceArea =>
      lat >= 6.5 && lat <= 35.7 && lng >= 68.1 && lng <= 97.4;
}

/// A place returned by the backend geocoder.
class PlaceSuggestion {
  final double lat;
  final double lng;
  final String label;

  const PlaceSuggestion({
    required this.lat,
    required this.lng,
    required this.label,
  });

  factory PlaceSuggestion.fromJson(Map<String, dynamic> json) {
    final lat =
        (json['lat'] as num?)?.toDouble() ??
        double.tryParse(json['lat']?.toString() ?? '');
    final lng =
        (json['lng'] as num?)?.toDouble() ??
        double.tryParse(json['lng']?.toString() ?? '');
    if (lat == null || lng == null) {
      throw const FormatException('Suggestion missing coordinates');
    }
    return PlaceSuggestion(
      lat: lat,
      lng: lng,
      label: (json['label'] ?? '').toString(),
    );
  }
}

/// Geocoding against the existing backend (Stadia-backed, India-only).
///
/// IMPORTANT: the backend is India-guarded — every ride request with
/// non-India coordinates is rejected with 422. Pickup/destination points
/// therefore default to Bengaluru, not San Francisco.
class GeocodingService {
  GeocodingService._();

  /// Bengaluru city centre (backend service area is India-only).
  static const GeoPoint defaultPickup = GeoPoint(12.9716, 77.5946);

  static final ApiClient _api = ApiClient.instance;

  /// Forward search via `GET /geocode/search`. Returns India-only results.
  /// Throws [ApiException] on network/HTTP errors (incl. 502 when the
  /// backend's upstream geocoder is unavailable).
  static Future<List<PlaceSuggestion>> search(String query) async {
    final trimmed = normaliseQuery(query).trim();
    if (trimmed.length < 2) return const [];
    final response = await _api.getJson(
      '/geocode/search',
      queryParameters: {'query': trimmed},
    );
    if (response is! List) return const [];
    final out = <PlaceSuggestion>[];
    for (final entry in response) {
      if (entry is! Map<String, dynamic>) continue;
      try {
        out.add(PlaceSuggestion.fromJson(entry));
      } on FormatException {
        continue; // skip malformed entries
      }
    }
    return out;
  }

  /// Autocomplete via `GET /geocode/suggest` (min 3 chars, backend enforced).
  /// Focused around [bias] (the confirmed pickup) so suggestions stay local —
  /// same behaviour as the website's `geocodeApi.suggest(query, pickupPoint)`.
  static Future<List<PlaceSuggestion>> suggest(
    String query, {
    GeoPoint? bias,
  }) async {
    final trimmed = normaliseQuery(query);
    if (trimmed.length < 3) return const [];
    final point = bias ?? defaultPickup;
    final response = await _api.getJson(
      '/geocode/suggest',
      queryParameters: {'query': trimmed, 'lat': point.lat, 'lng': point.lng},
    );
    if (response is! List) return const [];
    final out = <PlaceSuggestion>[];
    for (final entry in response) {
      if (entry is! Map<String, dynamic>) continue;
      try {
        out.add(PlaceSuggestion.fromJson(entry));
      } on FormatException {
        continue;
      }
    }
    return out;
  }

  /// Resolves free text to a single point: first backend search hit.
  /// Returns null when the search returns no results (caller decides the UX).
  static Future<PlaceSuggestion?> resolve(String query) async {
    final results = await search(query);
    return results.isEmpty ? null : results.first;
  }

  /// Common local typos the website fixes client-side before searching
  /// (frontend/src/services/api.js `COMMON_LOCATION_TYPOS`) — same list, so a
  /// query typed in the app resolves to the same place as on the website.
  static const Map<String, String> _typos = {
    'chruch': 'church',
    'churh': 'church',
    'indranagar': 'indiranagar',
    'indiranagr': 'indiranagar',
    'banglore': 'bengaluru',
    'bangluru': 'bengaluru',
  };

  static String normaliseQuery(String query) => query
      .split(RegExp(r'(\s+)'))
      .map((part) => _typos[part.toLowerCase()] ?? part)
      .join();
}
