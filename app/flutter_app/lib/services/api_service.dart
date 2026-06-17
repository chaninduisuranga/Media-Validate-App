import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiService {
  // This is your laptop's current Wi-Fi IP address (10.194.146.164).
  // This single address works perfectly for BOTH your connected Phone and the Emulator!
  static const String baseUrl =
      'https://ad651a9f-1e89-4a7c-ad18-449298cef4a1-dev.e1-us-east-azure.choreoapis.dev/media-auth-app/media-go-backend/v1.0/api';

  static Future<Map<String, dynamic>> _safeRequest(
    Future<http.Response> Function() requestFn, {
    int retries = 3,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    Exception? lastException;

    for (int i = 0; i < retries; i++) {
      try {
        final response = await requestFn().timeout(timeout);
        if (response.statusCode >= 500) {
          throw Exception('Server error: ${response.statusCode}');
        }
        return json.decode(response.body);
      } catch (e) {
        lastException = Exception(e.toString());
        if (i < retries - 1) {
          await Future.delayed(Duration(seconds: i + 1));
          continue;
        }
      }
    }
    throw lastException ?? Exception('Unknown network error');
  }

  static Future<Map<String, dynamic>> validateMedia(
    File file,
    dynamic userId,
  ) async {
    // Use a longer timeout (3 min) because the Go server relays to Hugging Face
    // which may take 30-90s. Retries kept to 1 to avoid duplicate HF requests.
    return _safeRequest(
      () async {
        var request = http.MultipartRequest(
          'POST',
          Uri.parse('$baseUrl/validate'),
        );
        request.files
            .add(await http.MultipartFile.fromPath('file', file.path));
        request.fields['user_id'] = userId.toString();

        var streamedResponse = await request.send();
        return await http.Response.fromStream(streamedResponse);
      },
      timeout: const Duration(minutes: 3),
      retries: 1,
    );
  }

  static Future<Map<String, dynamic>> signup(Map<String, dynamic> data) async {
    return _safeRequest(
      () => http.post(
        Uri.parse('$baseUrl/signup'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      ),
    );
  }

  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    return _safeRequest(
      () => http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email, 'password': password}),
      ),
    );
  }

  static Future<Map<String, dynamic>> updateUser(
    dynamic id,
    Map<String, dynamic> data,
  ) async {
    return _safeRequest(
      () => http.put(
        Uri.parse('$baseUrl/user/$id'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      ),
    );
  }

  static Future<Map<String, dynamic>> deleteUser(dynamic id) async {
    return _safeRequest(
      () => http.delete(
        Uri.parse('$baseUrl/user/$id'),
        headers: {'Content-Type': 'application/json'},
      ),
    );
  }

  static Future<Map<String, dynamic>> submitRating(
    Map<String, dynamic> data,
  ) async {
    return _safeRequest(
      () => http.post(
        Uri.parse('$baseUrl/rate'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      ),
    );
  }

  static Future<Map<String, dynamic>> getAnalytics(dynamic userId) async {
    return _safeRequest(
      () => http.get(Uri.parse('$baseUrl/user/$userId/analytics')),
    );
  }

  static Future<Map<String, dynamic>> getHistory(dynamic userId) async {
    return _safeRequest(
      () => http.get(Uri.parse('$baseUrl/user/$userId/history')),
    );
  }
}
