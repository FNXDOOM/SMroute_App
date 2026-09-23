class RideRequestRecord {
  final int id;
  final double pickupLat;
  final double pickupLng;
  final double destLat;
  final double destLng;
  final String status;
  final String? h3Index;
  final int? clusterId;
  final int? virtualStopId;

  /// Whether this ride is a carpool (pooled with other riders) or a private
  /// ride. The booking choice the backend echoes back; defaults to shared.
  final bool isShared;

  /// Fine per-rider carpool stage (`carpool_status`). Null for a private ride
  /// or a record written before the backend tracked the carpool axis; see
  /// [CarpoolStage.fromRide] for the fallback.
  final String? carpoolStatus;
  final DateTime? requestTime;
  // Human-readable labels (available when booked via the mobile app)
  final String? pickupLabelText;
  final String? destinationLabelText;
  final String? rideOptionId;
  final String? rideOptionName;
  final String? rideOptionPrice;

  const RideRequestRecord({
    required this.id,
    required this.pickupLat,
    required this.pickupLng,
    required this.destLat,
    required this.destLng,
    required this.status,
    this.h3Index,
    this.clusterId,
    this.virtualStopId,
    this.isShared = true,
    this.carpoolStatus,
    this.requestTime,
    this.pickupLabelText,
    this.destinationLabelText,
    this.rideOptionId,
    this.rideOptionName,
    this.rideOptionPrice,
  });

  /// A copy of this record with a new backend status — used to keep the
  /// active-ride UI in step with authoritative state between polls.
  RideRequestRecord copyWithStatus(String newStatus) {
    return RideRequestRecord(
      id: id,
      pickupLat: pickupLat,
      pickupLng: pickupLng,
      destLat: destLat,
      destLng: destLng,
      status: newStatus,
      h3Index: h3Index,
      clusterId: clusterId,
      virtualStopId: virtualStopId,
      isShared: isShared,
      carpoolStatus: carpoolStatus,
      requestTime: requestTime,
      pickupLabelText: pickupLabelText,
      destinationLabelText: destinationLabelText,
      rideOptionId: rideOptionId,
      rideOptionName: rideOptionName,
      rideOptionPrice: rideOptionPrice,
    );
  }

  static double _parseCoord(dynamic raw) {
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw) ?? 0.0;
    return 0.0;
  }

  factory RideRequestRecord.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final parsedId = rawId is int
        ? rawId
        : int.tryParse(rawId?.toString() ?? '');
    if (parsedId == null) {
      throw const FormatException('Ride record missing valid id');
    }
    return RideRequestRecord(
      id: parsedId,
      pickupLat: _parseCoord(json['pickup_lat']),
      pickupLng: _parseCoord(json['pickup_lng']),
      destLat: _parseCoord(json['dest_lat']),
      destLng: _parseCoord(json['dest_lng']),
      status: (json['status'] ?? 'pending').toString(),
      h3Index: json['h3_index']?.toString(),
      clusterId: json['cluster_id'] == null ? null : int.tryParse(json['cluster_id'].toString()),
      virtualStopId: json['virtual_stop_id'] == null
          ? null
          : int.tryParse(json['virtual_stop_id'].toString()),
      isShared: json['is_shared'] == null
          ? true
          : json['is_shared'].toString() == 'true',
      carpoolStatus: json['carpool_status']?.toString(),
      requestTime: json['request_time'] == null
          ? null
          : DateTime.tryParse(json['request_time'].toString()),
      pickupLabelText: json['pickup_label']?.toString(),
      destinationLabelText: json['destination_label']?.toString(),
      rideOptionId: json['ride_option_id']?.toString(),
      rideOptionName: json['ride_option_name']?.toString(),
      rideOptionPrice: json['ride_option_price']?.toString(),
    );
  }

  String get pickupLabel =>
      pickupLabelText?.isNotEmpty == true
          ? pickupLabelText!
          : '${pickupLat.toStringAsFixed(4)}, ${pickupLng.toStringAsFixed(4)}';

  String get destinationLabel =>
      destinationLabelText?.isNotEmpty == true
          ? destinationLabelText!
          : '${destLat.toStringAsFixed(4)}, ${destLng.toStringAsFixed(4)}';
}
