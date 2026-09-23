import '../models/ride_request_record.dart';
import '../services/api_client.dart';
import '../services/geocoding_service.dart';

/// A vehicle from `GET /vehicle/` (backend VehicleResponse).
class DriverVehicle {
  final int id;
  final String licensePlate;
  final int capacity;
  final String status;
  final int? driverUserId;
  final double? lat;
  final double? lng;

  /// Pooled route this vehicle is currently running, if the optimizer assigned
  /// one. Drives the driver console's route map.
  final String? assignedRouteId;

  const DriverVehicle({
    required this.id,
    required this.licensePlate,
    required this.capacity,
    required this.status,
    this.driverUserId,
    this.lat,
    this.lng,
    this.assignedRouteId,
  });

  /// Same vehicle with a new duty status and/or position — keeps every other
  /// field, including the pooled route the optimizer assigned to it.
  DriverVehicle copyWith({String? status, double? lat, double? lng}) =>
      DriverVehicle(
        id: id,
        licensePlate: licensePlate,
        capacity: capacity,
        status: status ?? this.status,
        driverUserId: driverUserId,
        lat: lat ?? this.lat,
        lng: lng ?? this.lng,
        assignedRouteId: assignedRouteId,
      );

  static int? _parseInt(dynamic raw) =>
      raw == null ? null : int.tryParse(raw.toString());

  static double? _parseDouble(dynamic raw) {
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw);
    return null;
  }

  factory DriverVehicle.fromJson(Map<String, dynamic> json) {
    final id = _parseInt(json['id']);
    if (id == null) {
      throw const FormatException('Vehicle record missing valid id');
    }
    return DriverVehicle(
      id: id,
      licensePlate: (json['license_plate'] ?? '').toString(),
      capacity: _parseInt(json['capacity']) ?? 4,
      status: (json['status'] ?? 'idle').toString(),
      driverUserId: _parseInt(json['driver_user_id']),
      lat: _parseDouble(json['lat']),
      lng: _parseDouble(json['lng']),
      assignedRouteId: json['assigned_route_id']?.toString(),
    );
  }
}

/// Driver-side operations — the website's DriverView surface:
///
///   - pick "my vehicle": `GET /vehicle/`, prefer one whose `driver_user_id`
///     matches the signed-in user (site: a dropdown, pre-selected when the
///     vehicle is registered to this driver)
///   - go on/off duty: `PATCH /vehicle/{id}` status active|idle
///   - push position: `POST /tracking/vehicles/{id}/location` (GPS)
///   - accept / advance / complete a ride: `PATCH /rides/{id}/status`
///     (completing also returns the vehicle to idle, like the site)
class DriverService {
  DriverService._();
  static final DriverService instance = DriverService._();

  final ApiClient _api = ApiClient.instance;

  Future<List<DriverVehicle>> listVehicles() async {
    final response = await _api.getJson('/vehicle/');
    final raw = response is List ? response : const [];
    final items = <DriverVehicle>[];
    for (final entry in raw) {
      if (entry is! Map<String, dynamic>) continue;
      try {
        items.add(DriverVehicle.fromJson(entry));
      } on FormatException {
        continue;
      }
    }
    return items;
  }

  /// The vehicle this driver should control: one registered to their user id,
  /// else null (UI shows the picker).
  Future<DriverVehicle?> findMyVehicle(int userId) async {
    final vehicles = await listVehicles();
    for (final v in vehicles) {
      if (v.driverUserId == userId) return v;
    }
    return null;
  }

  /// The pooled route plan this vehicle is running: `GET /route/history/{id}`
  /// (drivers may read their own route plans). Null when the route is gone.
  Future<Map<String, dynamic>?> fetchRoutePlan(String routeId) async {
    try {
      final response = await _api.getJson('/route/history/$routeId');
      return response is Map<String, dynamic> ? response : null;
    } on ApiException {
      return null;
    }
  }

  Future<void> setVehicleStatus(int vehicleId, String status) async {
    await _api.patchJson(
      '/vehicle/$vehicleId',
      body: <String, dynamic>{'status': status},
    );
  }

  /// Pushes a real GPS fix so the vehicle moves on every client's map.
  Future<void> pushLocation({
    required int vehicleId,
    required GeoPoint position,
  }) async {
    await _api.postJson(
      '/tracking/vehicles/$vehicleId/location',
      body: <String, dynamic>{'lat': position.lat, 'lng': position.lng},
    );
  }

  /// All rides (driver dispatch board). The backend caps this — the website
  /// asks for 50.
  Future<List<RideRequestRecord>> fetchBoard({int limit = 50}) async {
    final response = await _api.getJson(
      '/rides/',
      queryParameters: {'limit': limit},
    );
    final raw = response is List
        ? response
        : (response is Map<String, dynamic>
              ? response['rides'] as List<dynamic>? ?? const []
              : const []);
    final items = <RideRequestRecord>[];
    for (final entry in raw) {
      if (entry is! Map<String, dynamic>) continue;
      try {
        items.add(RideRequestRecord.fromJson(entry));
      } on FormatException {
        continue;
      }
    }
    return items;
  }

  /// Advances a ride's status. Completing/cancelling a ride also returns the
  /// vehicle to idle (site `handleStatusUpdate`).
  Future<void> updateRideStatus({
    required int rideId,
    required String status,
    int? vehicleId,
  }) async {
    await _api.patchJson(
      '/rides/$rideId/status',
      body: <String, dynamic>{'status': status},
    );
    if (vehicleId != null &&
        (status == 'completed' || status == 'cancelled')) {
      try {
        await setVehicleStatus(vehicleId, 'idle');
      } on ApiException {
        // Vehicle status is a nicety here — never mask the ride update.
      }
    }
  }
}
