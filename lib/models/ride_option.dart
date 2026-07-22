class RideOption {
  final String id;
  final String name;
  final String description;
  final String eta;
  final String priceRange;
  final int seats;
  final String iconEmoji;

  RideOption({
    required this.id,
    required this.name,
    required this.description,
    required this.eta,
    required this.priceRange,
    required this.seats,
    required this.iconEmoji,
  }) {
    if (seats < 1) throw ArgumentError('seats must be >= 1');
  }
}
