import '../services/geocoding_service.dart';
import 'vehicle_animation.dart' show distanceMeters;

/// How a route is drawn: the client's own trip line, or the pooled route's legs
/// one by one. Shared by the passenger map and the driver's route map.
enum RouteDisplayMode { single, segments }

/// Straight-line distance, wrapped so the [SharedRoute.distanceMeters] field
/// cannot shadow the shared geo helper inside the class body.
double _straightLineMeters(GeoPoint from, GeoPoint to) => distanceMeters(from, to);

// The backend sends typed JSON, but a malformed or partial payload must degrade
// to "nothing to draw" rather than throw — the map always has the rider's own
// line to fall back on.
int _asInt(dynamic value, [int fallback = 0]) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

int? _asOptionalInt(dynamic value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

double _asDouble(dynamic value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

double? _asOptionalDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

/// One driving leg of a pooled route: the stretch between two consecutive stops
/// of the vehicle serving this ride.
///
/// Named `SharedRouteLeg` rather than `RouteLeg` because the UI kit already has
/// a `RouteLeg` widget (a pickup → drop-off row) that every screen imports.
class SharedRouteLeg {
  final int index;
  final List<GeoPoint> points;
  final double distanceMeters;
  final double durationSeconds;

  /// Stop sequence this leg starts from / ends at. Null when the backend could
  /// not line the legs up with the stop list, in which case the leg is drawn
  /// but not attributed to a stop.
  final int? fromSequence;
  final int? toSequence;

  const SharedRouteLeg({
    required this.index,
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
    this.fromSequence,
    this.toSequence,
  });

  static SharedRouteLeg? fromJson(Map<String, dynamic> json) {
    final points = SharedRoute.parsePoints(json['geometry']);
    if (points.length < 2) return null;
    return SharedRouteLeg(
      index: _asInt(json['index']),
      points: points,
      distanceMeters: _asDouble(json['distance_meters']),
      durationSeconds: _asDouble(json['duration_seconds']),
      fromSequence: _asOptionalInt(json['from_sequence']),
      toSequence: _asOptionalInt(json['to_sequence']),
    );
  }
}

/// A stop on the pooled route — a boarding point or a drop-off.
class RouteStop {
  final int sequence;
  final GeoPoint point;
  final String waypointType; // depot | pickup | destination
  final int passengerCount;

  /// True when this stop belongs to the signed-in passenger's own ride.
  final bool isMine;

  /// Walking distance from this passenger's original pickup to this stop
  /// (backend `walk_meters`). Only set on the passenger's own pickup stop.
  final double? walkMeters;

  /// Rides served at this stop. The driver's route plan carries them; the
  /// passenger's view does not (the backend keeps other riders private there).
  final List<int> passengerIds;

  const RouteStop({
    required this.sequence,
    required this.point,
    required this.waypointType,
    required this.passengerCount,
    required this.isMine,
    this.walkMeters,
    this.passengerIds = const [],
  });

  bool get isPickup => waypointType == 'pickup';
  bool get isDestination => waypointType == 'destination';
  bool get isDepot => waypointType == 'depot';

  static RouteStop? fromJson(Map<String, dynamic> json) {
    final lat = _asOptionalDouble(json['lat']);
    final lng = _asOptionalDouble(json['lng']);
    if (lat == null || lng == null) return null;
    return RouteStop(
      sequence: _asInt(json['sequence']),
      point: GeoPoint(lat, lng),
      waypointType: (json['waypoint_type'] ?? '').toString(),
      passengerCount: _asInt(json['passenger_count']),
      isMine: json['is_mine'] == true,
      walkMeters: _asOptionalDouble(json['walk_meters']),
    );
  }
}

/// The stop a driver should head to next, and how far away it is.
class RouteNextStop {
  const RouteNextStop({
    required this.stop,
    required this.index,
    this.distanceMeters,
    this.minutes,
  });

  final RouteStop stop;

  /// Position of the stop on the route (index into [SharedRoute.stops]).
  final int index;

  /// Straight-line metres from the vehicle, or null when its position is
  /// unknown (no GPS fix pushed yet).
  final double? distanceMeters;
  final int? minutes;
}

/// The pooled route this ride is part of, as `GET /rides/{id}/route` returns it.
///
/// A ride only has one when it went through the pooling pipeline (clustering +
/// route optimization). A ride a driver accepted manually is deliberately
/// unlinked from its virtual stop by the backend, so it has no shared route and
/// the map keeps drawing the passenger's own line.
class SharedRoute {
  final String routeId;
  final int vehicleId;
  final String provider;

  /// Which model produced it: `pdp` (pickups + drop-offs) or the older
  /// `cvrp` pickups-only fallback.
  final String problem;

  final List<GeoPoint> geometry;
  final List<SharedRouteLeg> legs;
  final List<RouteStop> stops;
  final int? myPickupSequence;
  final int? myDestinationSequence;
  final List<int> myLegIndices;
  final double distanceMeters;
  final double durationSeconds;

  /// Whether the assigned driver has accepted the run yet. The passenger's
  /// route view carries it as `driver_accepted`; the driver's plan carries it
  /// under `route_metadata`.
  final bool driverAccepted;

  /// The route plan's own state: `solved` | `completed` | `cancelled` | ...
  final String routeStatus;

  /// This passenger's fine carpool stage, when the endpoint carries it.
  final String? carpoolStatus;

  /// True when this route is a carpool run (driver's route plan metadata).
  final bool isCarpoolRun;

  /// `accepted` | `completed` for a carpool run, else null.
  final String? carpoolRunStatus;

  const SharedRoute({
    required this.routeId,
    required this.vehicleId,
    required this.provider,
    required this.problem,
    required this.geometry,
    required this.legs,
    required this.stops,
    required this.myLegIndices,
    this.myPickupSequence,
    this.myDestinationSequence,
    this.distanceMeters = 0,
    this.durationSeconds = 0,
    this.driverAccepted = false,
    this.routeStatus = 'solved',
    this.carpoolStatus,
    this.isCarpoolRun = false,
    this.carpoolRunStatus,
  });

  /// The only case where the map's single-line/segments toggle means anything:
  /// a route with several legs to draw one by one.
  bool get isMultiStop => legs.length > 1;

  /// Legs as plain point lists, ready for the map's segment renderer.
  List<List<GeoPoint>> get legPoints =>
      [for (final leg in legs) leg.points];

  /// The stop this passenger boards at, or null when the route does not name
  /// it (the passenger's own pickup stop carries the walking distance).
  RouteStop? get myPickupStop {
    final sequence = myPickupSequence;
    if (sequence == null) return null;
    for (final stop in stops) {
      if (stop.sequence == sequence && stop.isPickup) return stop;
    }
    return null;
  }

  /// The next stop that still has work: the first stop on the route carrying a
  /// ride that has not finished. [finishedRideIds] is the dispatch board's
  /// terminal set, and [from] the vehicle's last known position.
  ///
  /// Only a route built from `GET /route/history/{id}` names the rides at each
  /// stop ([RouteStop.passengerIds]); the passenger's pooled view keeps other
  /// riders private, so there this returns null and the map shows no callout.
  RouteNextStop? nextPendingStop({
    Set<int> finishedRideIds = const {},
    GeoPoint? from,
  }) {
    for (var index = 0; index < stops.length; index++) {
      final stop = stops[index];
      if (stop.isDepot || stop.passengerIds.isEmpty) continue;
      final stillPending =
          stop.passengerIds.any((rideId) => !finishedRideIds.contains(rideId));
      if (!stillPending) continue;
      final metres = from == null ? null : _straightLineMeters(from, stop.point);
      return RouteNextStop(
        stop: stop,
        index: index,
        distanceMeters: metres,
        minutes: metres == null ? null : minutesFor(metres),
      );
    }
    return null;
  }

  /// Minutes to cover [meters] at this route's own average speed, or null when
  /// the backend gave no duration to derive one from.
  int? minutesFor(double meters) {
    if (distanceMeters <= 0 || durationSeconds <= 0) return null;
    final seconds = meters / (distanceMeters / durationSeconds);
    final minutes = (seconds / 60).round();
    return minutes < 1 ? 1 : minutes;
  }

  static List<GeoPoint> parsePoints(dynamic raw) {
    final points = <GeoPoint>[];
    if (raw is List) {
      for (final entry in raw) {
        if (entry is List && entry.length >= 2) {
          final lng = _asOptionalDouble(entry[0]);
          final lat = _asOptionalDouble(entry[1]);
          if (lat != null && lng != null) points.add(GeoPoint(lat, lng));
        }
      }
    }
    return points;
  }

  /// Null when there is nothing drawable — the caller then shows the rider's
  /// own pickup → drop-off line instead.
  static SharedRoute? fromJson(Map<String, dynamic> json) {
    final legs = <SharedRouteLeg>[];
    final rawLegs = json['legs'];
    if (rawLegs is List) {
      for (final entry in rawLegs) {
        if (entry is Map<String, dynamic>) {
          final leg = SharedRouteLeg.fromJson(entry);
          if (leg != null) legs.add(leg);
        }
      }
    }

    final stops = <RouteStop>[];
    final rawStops = json['stops'];
    if (rawStops is List) {
      for (final entry in rawStops) {
        if (entry is Map<String, dynamic>) {
          final stop = RouteStop.fromJson(entry);
          if (stop != null) stops.add(stop);
        }
      }
    }

    final geometry = parsePoints(json['geometry']);
    if (geometry.length < 2 && legs.isEmpty) return null;

    final myLegIndices = <int>[];
    final rawMyLegs = json['my_leg_indices'];
    if (rawMyLegs is List) {
      for (final entry in rawMyLegs) {
        final index = _asOptionalInt(entry);
        if (index != null) myLegIndices.add(index);
      }
    }

    return SharedRoute(
      routeId: (json['route_id'] ?? '').toString(),
      vehicleId: _asInt(json['vehicle_id'], -1),
      provider: (json['provider'] ?? 'unknown').toString(),
      problem: (json['problem'] ?? 'pdp').toString(),
      geometry: geometry,
      legs: legs,
      stops: stops,
      myLegIndices: myLegIndices,
      myPickupSequence: _asOptionalInt(json['my_pickup_sequence']),
      myDestinationSequence: _asOptionalInt(json['my_destination_sequence']),
      distanceMeters: _asDouble(json['total_distance_meters']),
      durationSeconds: _asDouble(json['estimated_duration_seconds']),
      driverAccepted: json['driver_accepted'] == true,
      routeStatus: (json['route_status'] ?? 'solved').toString(),
      carpoolStatus: json['carpool_status']?.toString(),
    );
  }

  /// Maps a `GET /route/history/{route_id}` route plan — the driver's view of
  /// the same pooled route — onto this model, so one map widget and one toggle
  /// serve both clients. Returns null when there is nothing to draw.
  static SharedRoute? fromRoutePlanJson(Map<String, dynamic> json) {
    final rawMetadata = json['route_metadata'];
    final metadata = rawMetadata is Map<String, dynamic>
        ? rawMetadata
        : const <String, dynamic>{};

    final stops = <RouteStop>[];
    final rawWaypoints = json['waypoints'];
    if (rawWaypoints is List) {
      for (final entry in rawWaypoints) {
        if (entry is! Map<String, dynamic>) continue;
        final lat = _asOptionalDouble(entry['lat']);
        final lng = _asOptionalDouble(entry['lng']);
        if (lat == null || lng == null) continue;
        final passengerIds = _parseIds(entry['passenger_ids']);
        stops.add(RouteStop(
          sequence: _asInt(entry['sequence']),
          point: GeoPoint(lat, lng),
          waypointType: (entry['waypoint_type'] ?? '').toString(),
          passengerCount: passengerIds.length,
          isMine: false,
          passengerIds: passengerIds,
        ));
      }
    }
    stops.sort((a, b) => a.sequence.compareTo(b.sequence));

    final geometry = parsePoints(_promoted(json, 'geometry', metadata));
    final rawLegs = _promoted(json, 'legs', metadata);
    final legs = <SharedRouteLeg>[];
    if (rawLegs is List) {
      for (final entry in rawLegs) {
        if (entry is! Map<String, dynamic>) continue;
        final leg = SharedRouteLeg.fromJson(entry);
        if (leg != null) legs.add(leg);
      }
    }

    if (geometry.length < 2 && legs.isEmpty) return null;

    // A leg is the drive between two consecutive stops, so attribute each one
    // when the router returned them all (the same rule the backend applies).
    final aligned = stops.length > 1 && legs.length == stops.length - 1;
    final attributed = <SharedRouteLeg>[
      for (var index = 0; index < legs.length; index++)
        if (aligned &&
            legs[index].fromSequence == null &&
            legs[index].toSequence == null)
          SharedRouteLeg(
            index: legs[index].index,
            points: legs[index].points,
            distanceMeters: legs[index].distanceMeters,
            durationSeconds: legs[index].durationSeconds,
            fromSequence: stops[index].sequence,
            toSequence: stops[index + 1].sequence,
          )
        else
          legs[index],
    ];

    return SharedRoute(
      routeId: (json['route_id'] ?? '').toString(),
      vehicleId: _asInt(json['vehicle_id'], -1),
      provider: (metadata['routing_provider'] ?? 'unknown').toString(),
      problem: (json['problem'] ?? metadata['problem'] ?? 'cvrp').toString(),
      geometry: geometry,
      legs: attributed,
      stops: stops,
      myLegIndices: const [],
      distanceMeters: _asDouble(
        json['total_distance_meters'] ?? metadata['distance_meters'],
      ),
      durationSeconds: _asDouble(
        json['estimated_duration_seconds'] ?? metadata['duration_seconds'],
      ),
      driverAccepted: metadata['driver_accepted'] == true,
      isCarpoolRun: metadata['carpool_run'] == true,
      carpoolRunStatus: metadata['carpool_run_status']?.toString(),
    );
  }

  /// The route-history endpoint promotes geometry and legs out of
  /// `route_metadata`, but older responses only carry them inside it — and a
  /// promoted-but-empty list has to fall back too, not win with nothing.
  static dynamic _promoted(
    Map<String, dynamic> json,
    String key,
    Map<String, dynamic> metadata,
  ) {
    final value = json[key];
    if (value is List && value.isNotEmpty) return value;
    return metadata[key];
  }

  static List<int> _parseIds(dynamic raw) {
    if (raw is! List) return const [];
    final ids = <int>[];
    for (final entry in raw) {
      final id = _asOptionalInt(entry);
      if (id != null) ids.add(id);
    }
    return ids;
  }
}
