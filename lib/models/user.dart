class AppUser {
  final String name;
  final String email;
  final String phone;

  const AppUser({required this.name, required this.email, required this.phone});

  String get firstName => name.trim().split(' ').first;
}
