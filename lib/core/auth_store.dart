import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthStore {
  static String? accessToken;
  static String? refreshToken;

  static String get baseUrl {
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    if (fromEnv.isNotEmpty) return fromEnv;
    return 'http://localhost:3000/api/v1';
  }

  static Future<http.Response> post(String path, Map<String, dynamic> body, {bool auth = true}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (auth && accessToken != null) 'Authorization': 'Bearer $accessToken',
    };
    return http.post(Uri.parse('$baseUrl$path'), headers: headers, body: jsonEncode(body));
  }

  static Future<http.Response> get(String path, {Map<String, String>? query, bool auth = true}) async {
    final headers = <String, String>{
      if (auth && accessToken != null) 'Authorization': 'Bearer $accessToken',
    };
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    return http.get(uri, headers: headers);
  }

  static Future<http.Response> patch(String path, Map<String, dynamic> body, {bool auth = true}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (auth && accessToken != null) 'Authorization': 'Bearer $accessToken',
    };
    return http.patch(Uri.parse('$baseUrl$path'), headers: headers, body: jsonEncode(body));
  }

  static Future<http.Response> delete(String path, {bool auth = true}) async {
    final headers = <String, String>{
      if (auth && accessToken != null) 'Authorization': 'Bearer $accessToken',
    };
    return http.delete(Uri.parse('$baseUrl$path'), headers: headers);
  }
}