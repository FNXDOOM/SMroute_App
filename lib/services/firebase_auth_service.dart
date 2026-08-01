import 'dart:convert';
import 'package:http/http.dart' as http;

/// Service for handling Firebase Authentication & Syncing with FastAPI Backend
class FirebaseAuthService {
  final String backendBaseUrl;

  FirebaseAuthService({required this.backendBaseUrl});

  /// Exchange Firebase User details / ID Token with FastAPI Backend
  Future<Map<String, dynamic>> syncWithBackend({
    required String firebaseUid,
    required String email,
    required String displayName,
    required String idToken,
  }) async {
    final url = Uri.parse('$backendBaseUrl/auth/firebase-login');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'uid': firebaseUid,
        'email': email,
        'name': displayName,
        'id_token': idToken,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data; // Returns {'access_token': '...', 'token_type': 'bearer', 'user': {...}}
    } else {
      throw Exception('Backend sync failed: ${response.body}');
    }
  }
}
