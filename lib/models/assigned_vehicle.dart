/// Vehicle assigned to a ride, as returned by `GET /rides/{id}/vehicle`
/// (backend/routers/rides.py) and updated live via `/tracking/ws`.
class AssignedVehicle {
  final int id;
  final String licensePlate;
  final String status;
  final double? lat;
  final double? lng;

  AssignedVehicle({
    required this.id,
    required this.licensePlate,
    required this.status,
    this.lat,
    this.lng,
  });

  static int _parseId(dynamic raw) {
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? '') ?? -1;
  }

  static double? _parseCoord(dynamic raw) {
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw);
    return null;
  }

  factory AssignedVehicle.fromJson(Map<String, dynamic> json) {
    return AssignedVehicle(
      id: _parseId(json['id']),
      licensePlate: (json['license_plate'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      lat: _parseCoord(json['lat']),
      lng: _parseCoord(json['lng']),
    );
  }

  AssignedVehicle copyWithLocation({double? lat, double? lng, String? status}) {
    return AssignedVehicle(
      id: id,
      licensePlate: licensePlate,
      status: status ?? this.status,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
    );
  }
}
