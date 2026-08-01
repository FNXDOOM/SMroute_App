class AppUser {
  final int? id;
  final String name;
  final String email;
  final String phone;
  final String role;
  final DateTime? createdAt;

  const AppUser({
    this.id,
    required this.name,
    required this.email,
    required this.phone,
    this.role = 'passenger',
    this.createdAt,
  });

  String get firstName => name.trim().split(' ').first;

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
      createdAt: createdAt,
    );
  }

  AppUser copyWithPhone(String phoneValue) => copyWith(phone: phoneValue);
}
