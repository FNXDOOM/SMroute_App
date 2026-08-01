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
    this.requestTime,
    this.pickupLabelText,
    this.destinationLabelText,
    this.rideOptionId,
    this.rideOptionName,
    this.rideOptionPrice,
  });

  factory RideRequestRecord.fromJson(Map<String, dynamic> json) {
    return RideRequestRecord(
      id: int.tryParse(json['id'].toString()) ?? 0,
      pickupLat: (json['pickup_lat'] as num?)?.toDouble() ?? 0.0,
      pickupLng: (json['pickup_lng'] as num?)?.toDouble() ?? 0.0,
      destLat: (json['dest_lat'] as num?)?.toDouble() ?? 0.0,
      destLng: (json['dest_lng'] as num?)?.toDouble() ?? 0.0,
      status: (json['status'] ?? 'pending').toString(),
      h3Index: json['h3_index']?.toString(),
      clusterId: json['cluster_id'] == null ? null : int.tryParse(json['cluster_id'].toString()),
      virtualStopId: json['virtual_stop_id'] == null
          ? null
          : int.tryParse(json['virtual_stop_id'].toString()),
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
