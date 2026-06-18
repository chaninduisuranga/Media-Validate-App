import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

class ApiService {
  static const String baseUrl =
      'https://ad651a9f-1e89-4a7c-ad18-449298cef4a1-dev.e1-us-east-azure.choreoapis.dev/media-auth-app/media-go-backend/v1.0/api';

  // Keep uploads small enough for Choreo/HF cold-start windows.
  // Original camera photos can timeout even when the model itself is fast.
  static const int _maxImageDim = 1280; // max width or height in pixels

  /// Normalize image uploads to a bounded JPEG payload.
  /// Returns compressed bytes, or null if the file is a video/unsupported type.
  static Future<Uint8List?> _maybeCompressImage(File file) async {
    final ext = p.extension(file.path).toLowerCase();
    final isImage = ['.jpg', '.jpeg', '.png', '.webp'].contains(ext);
    if (!isImage) return null; // videos: skip

    final compressed = await FlutterImageCompress.compressWithFile(
      file.absolute.path,
      minWidth: _maxImageDim,
      minHeight: _maxImageDim,
      quality: 82,
      format: CompressFormat.jpeg,
    );

    return compressed;
  }

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
    // Compress large images before uploading.
    // Camera photos (3-10MB) → compressed to ≤1MB → faster upload, no gateway timeout.
    final compressedBytes = await _maybeCompressImage(file);

    return _safeRequest(
      () async {
        var request = http.MultipartRequest(
          'POST',
          Uri.parse('$baseUrl/validate'),
        );

        if (compressedBytes != null) {
          // Use normalized JPEG bytes so original camera photos avoid gateway timeouts.
          request.files.add(
            http.MultipartFile.fromBytes(
              'file',
              compressedBytes,
              filename: '${p.basenameWithoutExtension(file.path)}.jpg',
            ),
          );
        } else {
          // Use original file (video or already-small image)
          request.files.add(
            await http.MultipartFile.fromPath('file', file.path),
          );
        }
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
