import '../models/assigned_vehicle.dart';
import '../models/vehicle_animation.dart';
import 'geocoding_service.dart';

/// Derives the moving-vehicle animation for a ride from the ride lifecycle.
///
/// The ride status stays the single source of truth: this only *projects* it
/// onto the map, so nothing here is a second state machine and no status is
/// invented. It is a direct port of the website's reference implementation
/// (`frontend/src/views/PassengerView.jsx` → `simDriver` + `mapVehicleAnimation`).
///
/// Why a synthetic start point exists at all: the backend's dispatch simulator
/// advances `assigned → arriving → in_progress → completed` on a 5 s timer
/// without ever writing `Vehicle.lat/lng` (`backend/services/background_jobs.py`
/// → `run_simulate_ride_dispatch_job`), and an admin/driver status change nulls
/// `ride.virtual_stop_id`, which makes `GET /rides/{id}/vehicle` return `null`
/// for the rest of the ride. So in the normal flow there is no driver telemetry
/// to draw at all. The site responds by placing the car a short distance from
/// the pickup and driving it in; this does the same. When a real fix *does*
/// exist (a driver app POSTed `/tracking/vehicles/{id}/location`) it always
/// wins over the synthetic point.
class RideVehicleAnimation {
  RideVehicleAnimation._();

  /// Reported when the backend has no vehicle for the ride. The website uses
  /// the same stand-in (`sim-driver`).
  static const String simulatedVehicleId = 'sim-driver';

  /// Site offsets, in degrees of longitude. The vehicle starts east of the
  /// pickup and slightly north of it (`PassengerView.jsx`: `pickup + (0.012,
  /// 0.0072)` for assigned, `(0.004, 0.0024)` for arriving), which at
  /// Bengaluru's latitude is roughly 1.3 km and 450 m away.
  static const double _assignedOffset = 0.012;
  static const double _arrivingOffset = 0.004;

  /// The site's animation durations. Longer for the earlier stage: the driver
  /// is further out, so the same visual journey takes more time.
  static const Duration _assignedDuration = Duration(seconds: 25);
  static const Duration _arrivingDuration = Duration(seconds: 12);

  /// Pickup → destination leg.
  static const Duration _inTransitDuration = Duration(seconds: 18);

  /// The animation for [status], or null when no vehicle should be drawn.
  ///
  /// Null for `pending`/`clustered` (no driver is assigned yet — the site shows
  /// only the pickup pulse) and for `completed`/`cancelled`/unknown statuses
  /// (movement must stop; see [LiveMap], which settles the vehicle where it is).
  static VehicleAnimation? forRide({
    required String? status,
    required GeoPoint? pickup,
    required GeoPoint? destination,
    List<GeoPoint> routeGeometry = const <GeoPoint>[],
    AssignedVehicle? vehicle,
  }) {
    final key = (status ?? '').toLowerCase();
    if (pickup == null) return null;

    // Real telemetry wins outright: when a vehicle has a live position the
    // map's tracking layer draws it (LiveMap's `vehicles`), so this derivation
    // must return nothing rather than fabricate a second, simulated path that
    // would hijack that marker. The stand-in car is only for the (common) case
    // where the backend reports no vehicle position at all.
    if (_livePoint(vehicle) != null) return null;

    switch (key) {
      case 'assigned':
      case 'arriving':
        final arriving = key == 'arriving';
        final start = _offsetFrom(
          pickup,
          arriving ? _arrivingOffset : _assignedOffset,
        );
        final path = <GeoPoint>[start, pickup];
        return VehicleAnimation(
          vehicleId: simulatedVehicleId,
          key: _key(simulatedVehicleId, key, path),
          path: path,
          duration: arriving ? _arrivingDuration : _assignedDuration,
        );

      case 'in_progress':
        final path = _pickupToDestination(routeGeometry, pickup, destination);
        if (path == null) return null;
        return VehicleAnimation(
          vehicleId: simulatedVehicleId,
          key: _key(simulatedVehicleId, key, path),
          path: path,
          duration: _inTransitDuration,
        );

      default:
        return null;
    }
  }

  /// The pickup → destination leg. Prefers the road geometry the backend
  /// already returns (`GET /routing/route`, reused via `RoutingService`), and
  /// degrades to a straight line exactly like the website when that call
  /// failed or has not landed yet.
  static List<GeoPoint>? _pickupToDestination(
    List<GeoPoint> routeGeometry,
    GeoPoint pickup,
    GeoPoint? destination,
  ) {
    if (routeGeometry.length >= 2) return routeGeometry;
    if (destination == null) return null;
    return <GeoPoint>[pickup, destination];
  }

  static GeoPoint? _livePoint(AssignedVehicle? vehicle) {
    final lat = vehicle?.lat;
    final lng = vehicle?.lng;
    if (vehicle == null || lat == null || lng == null) return null;
    if (!lat.isFinite || !lng.isFinite) return null;
    if (lat.abs() > 90 || lng.abs() > 180) return null;
    return GeoPoint(lat, lng);
  }

  static GeoPoint _offsetFrom(GeoPoint pickup, double offset) => GeoPoint(
        pickup.lat + offset * 0.6,
        pickup.lng + offset,
      );

  /// Identity of the motion. A rebuild with the same key must not restart the
  /// walk; a status change, a new vehicle, or route geometry arriving late all
  /// produce a new key and therefore a fresh — but continuous — walk.
  static String _key(String vehicleId, String status, List<GeoPoint> path) =>
      '$vehicleId:$status:${path.length}';
}
