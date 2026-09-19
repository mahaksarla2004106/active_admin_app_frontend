import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});
  @override
  String toString() => message;
}

class ApiClient {
  static const String baseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:3000/api/v1');

  static String? _accessToken;
  static String? _refreshToken;
  static String? _adminEmail;

  static Future<void> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('admin_access_token');
    _refreshToken = prefs.getString('admin_refresh_token');
    _adminEmail = prefs.getString('admin_email');
  }

  static bool get isLoggedIn => _accessToken != null;

  static String? get adminEmail => _adminEmail;

  static Future<void> saveSession(String access, String refresh, String email) async {
    _accessToken = access;
    _refreshToken = refresh;
    _adminEmail = email;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('admin_access_token', access);
    await prefs.setString('admin_refresh_token', refresh);
    await prefs.setString('admin_email', email);
  }

  static Future<void> logout() async {
    _accessToken = null;
    _refreshToken = null;
    _adminEmail = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('admin_access_token');
    await prefs.remove('admin_refresh_token');
    await prefs.remove('admin_email');
  }

  static Map<String, String> _headers({bool json = true}) => {
        if (json) 'Content-Type': 'application/json',
        if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
      };

  static Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    http.Response response;
    switch (method.toUpperCase()) {
      case 'GET':
        response = await http.get(uri, headers: _headers(json: false)).timeout(const Duration(seconds: 30));
      case 'POST':
        response = await http.post(uri, headers: _headers(), body: jsonEncode(body ?? {})).timeout(const Duration(seconds: 60));
      case 'PATCH':
        response = await http.patch(uri, headers: _headers(), body: jsonEncode(body ?? {})).timeout(const Duration(seconds: 60));
      case 'DELETE':
        response = await http.delete(uri, headers: _headers(json: false)).timeout(const Duration(seconds: 30));
      default:
        throw ApiException('Unsupported method $method');
    }
    return _unwrap(response);
  }

  static dynamic _unwrap(http.Response response) {
    dynamic data;
    try {
      data = jsonDecode(response.body);
    } catch (_) {
      data = null;
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (data is Map<String, dynamic>) {
        if (data.containsKey('data')) {
          final envelope = data['data'];
          if (envelope != null && (envelope is Map || envelope is List)) return envelope;
        }
        if (data.containsKey('error')) {
          final err = data['error'];
          return _normalizeError(err);
        }
        return data;
      }
      return data;
    }
    throw _errorFromResponse(response, data);
  }

  static dynamic _normalizeError(dynamic err) {
    if (err is List && err.isNotEmpty) {
      final first = err.first;
      if (first is Map && first.containsKey('constraints')) {
        return (first['constraints'] as Map).values.first;
      }
      if (first is String) return first;
      if (first is Map && first.containsKey('message')) return first['message'];
    }
    if (err is Map && err.containsKey('message')) return err['message'];
    if (err is String) return err;
    return 'Unknown server error';
  }

  static ApiException _errorFromResponse(http.Response response, dynamic data) {
    if (response.statusCode == 401) return ApiException('Session expired. Please log in again.', statusCode: 401);
    String message = 'Request failed (${response.statusCode})';
    if (data is Map<String, dynamic>) {
      if (data.containsKey('message')) {
        final m = data['message'];
        message = m is String ? m : jsonEncode(m);
      } else if (data.containsKey('error')) {
        message = _normalizeError(data['error']);
      }
    }
    return ApiException(message, statusCode: response.statusCode);
  }
}