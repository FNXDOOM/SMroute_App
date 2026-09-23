import 'package:flutter_test/flutter_test.dart';
import 'package:finalyr_app/models/user.dart';

/// Guards the client's reading of the backend's `driver_status`, which
/// `get_current_driver_user` now enforces on every driver endpoint.
void main() {
  Map<String, dynamic> userJson({
    required String role,
    required String status,
  }) =>
      {
        'id': 7,
        'name': 'Nikhil',
        'email': 'n@example.com',
        'phone': '9999999999',
        'role': role,
        'driver_status': status,
      };

  group('AppUser.driverStatus', () {
    test('adopts the wire value verbatim', () {
      final user = AppUser.fromJson(
        userJson(role: 'driver', status: 'pending_verification'),
      );
      expect(user.driverStatus, 'pending_verification');
    });

    test('treats a missing field as not yet approved', () {
      final user = AppUser.fromJson(<String, dynamic>{
        'id': 7,
        'name': 'Nikhil',
        'email': 'n@example.com',
        'phone': '9999999999',
        'role': 'driver',
      });
      expect(user.driverStatus, 'pending_verification');
    });

    test('survives copyWith from a profile edit', () {
      final user = AppUser.fromJson(
        userJson(role: 'driver', status: 'active'),
      ).copyWith(name: 'Nik');
      expect(user.driverStatus, 'active');
      expect(user.canDrive, isTrue);
    });
  });

  group('AppUser.canDrive', () {
    test('is the only combination the backend lets through', () {
      expect(
        AppUser.fromJson(userJson(role: 'driver', status: 'active')).canDrive,
        isTrue,
      );
      expect(
        AppUser.fromJson(
          userJson(role: 'driver', status: 'pending_verification'),
        ).canDrive,
        isFalse,
      );
      expect(
        AppUser.fromJson(userJson(role: 'driver', status: 'suspended'))
            .canDrive,
        isFalse,
      );
    });

    test('is false for a passenger even though they register as active', () {
      expect(
        AppUser.fromJson(userJson(role: 'passenger', status: 'active'))
            .canDrive,
        isFalse,
      );
    });
  });
}
