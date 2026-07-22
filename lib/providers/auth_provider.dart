import 'package:flutter/foundation.dart';
import '../models/user.dart';

class AuthProvider extends ChangeNotifier {
  AppUser? _currentUser;
  bool _isLoading = false;
  String? _error;

  // Getters
  AppUser? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _currentUser != null;

  /// Validates that none of the provided fields are empty or whitespace-only.
  bool _hasEmptyFields(List<String> fields) {
    return fields.any((f) => f.trim().isEmpty);
  }

  /// Simulates login with a 1-second delay.
  /// Requirements 3.1, 3.2, 3.3
  Future<void> login(String email, String password) async {
    if (_hasEmptyFields([email, password])) {
      _error = 'Please fill in all fields.';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    await Future.delayed(const Duration(seconds: 1));

    _currentUser = AppUser(
      name: 'Alex Rivera',
      email: email,
      phone: '+1 (555) 000-1234',
    );
    _isLoading = false;
    notifyListeners();
  }

  /// Simulates registration with a 1-second delay.
  /// Requirements 3.1, 3.2, 3.3
  Future<void> register(
    String name,
    String email,
    String phone,
    String password,
  ) async {
    if (_hasEmptyFields([name, email, phone, password])) {
      _error = 'Please fill in all fields.';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    await Future.delayed(const Duration(seconds: 1));

    _currentUser = AppUser(name: name, email: email, phone: phone);
    _isLoading = false;
    notifyListeners();
  }

  /// Clears the current user session.
  void logout() {
    _currentUser = null;
    notifyListeners();
  }
}
