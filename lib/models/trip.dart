enum TripStatus { completed, cancelled }

class Trip {
  final String id;
  final String date;
  final String from;
  final String to;
  final String fare;
  final String type;
  final TripStatus status;

  const Trip({
    required this.id,
    required this.date,
    required this.from,
    required this.to,
    required this.fare,
    required this.type,
    required this.status,
  });
}
