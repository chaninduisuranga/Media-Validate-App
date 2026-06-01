import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiService {
  // This is your laptop's current Wi-Fi IP address (10.194.146.164).
  // This single address works perfectly for BOTH your connected Phone and the Emulator!
  static const String baseUrl = 'http://10.194.146.164:8081/api';

  static Future<Map<String, dynamic>> validateMedia(
    File file,
    dynamic userId,
  ) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/validate'),
      );
      request.files.add(await http.MultipartFile.fromPath('file', file.path));
      request.fields['user_id'] = userId.toString();

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to connect to server: $e');
    }
  }

  static Future<Map<String, dynamic>> signup(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/signup'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );

      return json.decode(response.body);
    } catch (e) {
      throw Exception('Failed to signup: $e');
    }
  }

  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email, 'password': password}),
      );

      return json.decode(response.body);
    } catch (e) {
      throw Exception('Failed to login: $e');
    }
  }

  static Future<Map<String, dynamic>> updateUser(
    dynamic id,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/user/$id'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );

      return json.decode(response.body);
    } catch (e) {
      throw Exception('Failed to update profile: $e');
    }
  }

  static Future<Map<String, dynamic>> deleteUser(dynamic id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/user/$id'),
        headers: {'Content-Type': 'application/json'},
      );

      return json.decode(response.body);
    } catch (e) {
      throw Exception('Failed to delete account: $e');
    }
  }

  static Future<Map<String, dynamic>> submitRating(
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/rate'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );
      return json.decode(response.body);
    } catch (e) {
      throw Exception('Failed to submit rating: $e');
    }
  }

  static Future<Map<String, dynamic>> getAnalytics(dynamic userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/user/$userId/analytics'),
      );
      return json.decode(response.body);
    } catch (e) {
      throw Exception('Failed to fetch analytics: $e');
    }
  }

  static Future<Map<String, dynamic>> getHistory(dynamic userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/user/$userId/history'),
      );
      return json.decode(response.body);
    } catch (e) {
      throw Exception('Failed to fetch history: $e');
    }
  }
}
