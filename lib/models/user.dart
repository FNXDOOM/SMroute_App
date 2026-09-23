class AppUser {
  final int? id;
  final String name;
  final String email;
  final String phone;
  final String role;

  /// Backend `driver_status`: `active` | `pending_verification` | `suspended`.
  /// Every account carries it — a passenger registers as `active` but cannot
  /// drive — so it only means anything once [role] is `driver`.
  final String driverStatus;
  final DateTime? createdAt;

  const AppUser({
    this.id,
    required this.name,
    required this.email,
    required this.phone,
    this.role = 'passenger',
    this.driverStatus = 'pending_verification',
    this.createdAt,
  });

  /// A driver the backend will actually let through its driver endpoints.
  /// Endpoints behind `get_current_driver_user` reject any other combination,
  /// so this is what keeps the app from routing someone into a wall of 403s.
  bool get canDrive => role == 'driver' && driverStatus == 'active';

  String get firstName {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'Rider';
    return trimmed.split(RegExp(r'\s+')).first;
  }

  /// Safe single-letter avatar fallback — never throws on empty names.
  String get avatarLetter => firstName[0].toUpperCase();

  factory AppUser.fromJson(
    Map<String, dynamic> json, {
    String phoneFallback = '',
  }) {
    return AppUser(
      id: json['id'] == null ? null : int.tryParse(json['id'].toString()),
      name: (json['name'] ?? 'Rider').toString(),
      email: (json['email'] ?? '').toString(),
      phone: (json['phone'] ?? phoneFallback).toString(),
      role: (json['role'] ?? 'passenger').toString(),
      driverStatus: (json['driver_status'] ?? 'pending_verification').toString(),
      createdAt: json['created_at'] == null
          ? null
          : DateTime.tryParse(json['created_at'].toString()),
    );
  }

  AppUser copyWith({String? name, String? email, String? phone}) {
    return AppUser(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role,
      driverStatus: driverStatus,
      createdAt: createdAt,
    );
  }

  AppUser copyWithPhone(String phoneValue) => copyWith(phone: phoneValue);
}
