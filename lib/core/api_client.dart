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
  static const String baseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'https://activ-backend-production.up.railway.app/api/v1');

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
    bool isRetry = false,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    http.Response response;
    switch (method.toUpperCase()) {
      case 'GET':
        response = await http.get(uri, headers: _headers(json: false)).timeout(const Duration(seconds: 30));
        break;
      case 'POST':
        response = await http.post(uri, headers: _headers(), body: jsonEncode(body ?? {})).timeout(const Duration(seconds: 60));
        break;
      case 'PATCH':
        response = await http.patch(uri, headers: _headers(), body: jsonEncode(body ?? {})).timeout(const Duration(seconds: 60));
        break;
      case 'DELETE':
        response = await http.delete(uri, headers: _headers(json: false)).timeout(const Duration(seconds: 30));
        break;
      default:
        throw ApiException('Unsupported method $method');
    }

    if (response.statusCode == 401 && !isRetry && _refreshToken != null) {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        return request(method, path, body: body, query: query, isRetry: true);
      }
    }

    return _unwrap(response);
  }

  static Future<dynamic> uploadMultipart(
    String path,
    String fieldName,
    List<int> bytes,
    String filename, {
    bool isRetry = false,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final request = http.MultipartRequest('POST', uri);
    if (_accessToken != null) {
      request.headers['Authorization'] = 'Bearer $_accessToken';
    }
    
    request.files.add(
      http.MultipartFile.fromBytes(
        fieldName,
        bytes,
        filename: filename,
      ),
    );
    
    final streamedResponse = await request.send().timeout(const Duration(seconds: 120));
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 401 && !isRetry && _refreshToken != null) {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        return uploadMultipart(path, fieldName, bytes, filename, isRetry: true);
      }
    }

    return _unwrap(response);
  }

  static Future<bool> _tryRefresh() async {
    if (_refreshToken == null) return false;
    try {
      final uri = Uri.parse('$baseUrl/admin/auth/refresh');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': _refreshToken}),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        final envelope = data['data'] ?? data;
        final newAccess = envelope['accessToken'];
        final newRefresh = envelope['refreshToken'];
        if (newAccess != null && newRefresh != null) {
          await saveSession(newAccess, newRefresh, _adminEmail ?? '');
          return true;
        }
      }
    } catch (_) {
      // Ignore errors during refresh, it will just fall through and fail
    }
    await logout();
    return false;
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

class AdminApi {
  // Auth
  static Future<dynamic> login(String email, String password) => ApiClient.request('POST', '/admin/auth/login', body: {'email': email, 'password': password});

  // Dashboard
  static Future<dynamic> getDashboardOverview() => ApiClient.request('GET', '/admin/dashboard/overview');
  static Future<dynamic> getDashboardRevenue({int days = 30}) => ApiClient.request('GET', '/admin/dashboard/revenue?days=$days');
  static Future<dynamic> getDashboardBookings({int days = 30}) => ApiClient.request('GET', '/admin/dashboard/bookings?days=$days');

  // Venues
  static Future<dynamic> getVenues(Map<String, String>? query) => ApiClient.request('GET', '/admin/venues', query: query);
  static Future<dynamic> getVenueDetails(String id) => ApiClient.request('GET', '/admin/venues/$id');
  static Future<dynamic> updateVenueStatus(String id, String status) => ApiClient.request('PATCH', '/admin/venues/$id/status', body: {'status': status});

  // Activities (Catalog)
  static Future<dynamic> getActivities() => ApiClient.request('GET', '/admin/catalog/activities');
  static Future<dynamic> createActivity(String name, String code, String type) => ApiClient.request('POST', '/admin/catalog/activities', body: {'name': name, 'sportCode': code, 'type': type});
  static Future<dynamic> updateActivityStatus(String id, String action) => ApiClient.request('POST', '/admin/catalog/activities/$id/$action');

  // Users
  static Future<dynamic> getUsers(Map<String, String>? query) => ApiClient.request('GET', '/admin/users', query: query);
  static Future<dynamic> getUserDetails(String id) => ApiClient.request('GET', '/admin/users/$id');
  static Future<dynamic> updateUserStatus(String id, String target) => ApiClient.request('PATCH', '/admin/users/$id/status', body: {'status': target});
  static Future<dynamic> revokeUserSessions(String id) => ApiClient.request('POST', '/admin/users/$id/revoke-sessions');

  // Bookings
  static Future<dynamic> getBookings(Map<String, String>? query) => ApiClient.request('GET', '/admin/bookings', query: query);
  static Future<dynamic> getBookingDetails(String id) => ApiClient.request('GET', '/admin/bookings/$id');
  static Future<dynamic> cancelBooking(String id, String reason) => ApiClient.request('POST', '/admin/bookings/$id/cancel', body: {'reason': reason});

  // Payments / Refunds
  static Future<dynamic> getPayments(Map<String, String>? query) => ApiClient.request('GET', '/admin/payments', query: query);
  static Future<dynamic> getRefunds(Map<String, String>? query) => ApiClient.request('GET', '/admin/refunds', query: query);
  static Future<dynamic> processRefund(String id) => ApiClient.request('POST', '/admin/refunds/$id/process');
  static Future<dynamic> failRefund(String id) => ApiClient.request('POST', '/admin/refunds/$id/fail');

  // Coupons
  static Future<dynamic> getCoupons(Map<String, String>? query) => ApiClient.request('GET', '/admin/coupons', query: query);
  static Future<dynamic> createCoupon(Map<String, dynamic> body) => ApiClient.request('POST', '/admin/coupons', body: body);
  static Future<dynamic> updateCouponStatus(String id, String status) => ApiClient.request('PATCH', '/admin/coupons/$id/status', body: {'status': status});

  // Support Tickets
  static Future<dynamic> getSupportTickets(Map<String, String>? query) => ApiClient.request('GET', '/admin/support/tickets', query: query);
  static Future<dynamic> updateTicketStatus(String id, String status) => ApiClient.request('PATCH', '/admin/support/tickets/$id/status', body: {'status': status});

  // Content (FAQs, Policies, Banners)
  static Future<dynamic> getFaqs() => ApiClient.request('GET', '/admin/content/faqs');
  static Future<dynamic> createFaq(Map<String, dynamic> body) => ApiClient.request('POST', '/admin/content/faqs', body: body);
  static Future<dynamic> updateFaq(String id, Map<String, dynamic> body) => ApiClient.request('PATCH', '/admin/content/faqs/$id', body: body);
  static Future<dynamic> updateFaqStatus(String id, String status) => ApiClient.request('PATCH', '/admin/content/faqs/$id/status', body: {'status': status});
  
  static Future<dynamic> getPolicies() => ApiClient.request('GET', '/admin/content/policies');
  static Future<dynamic> createPolicy(Map<String, dynamic> body) => ApiClient.request('POST', '/admin/content/policies', body: body);
  static Future<dynamic> updatePolicyStatus(String id, String status) => ApiClient.request('PATCH', '/admin/content/policies/$id/status', body: {'status': status});
  
  static Future<dynamic> getBanners() => ApiClient.request('GET', '/admin/content/banners');
  static Future<dynamic> deleteBanner(String filename) => ApiClient.request('DELETE', '/admin/content/banners/$filename');
  static Future<dynamic> uploadBanner(List<int> bytes, String filename) => ApiClient.uploadMultipart('/admin/content/banners', 'file', bytes, filename);

  // Notifications
  static Future<dynamic> getNotificationStats() => ApiClient.request('GET', '/admin/notifications/stats');
  static Future<dynamic> broadcastNotification(String title, String body) => ApiClient.request('POST', '/admin/notifications/broadcast', body: {'title': title, 'body': body, 'all': true});

  // Feature Flags
  static Future<dynamic> getFeatureFlags() => ApiClient.request('GET', '/admin/feature-flags');
  static Future<dynamic> toggleFeatureFlag(String key, bool enabled) => ApiClient.request('PATCH', '/admin/feature-flags/$key/toggle', body: {'enabled': enabled});

  // Audit Logs
  static Future<dynamic> getAuditLogs({int page = 1, int limit = 20}) => ApiClient.request('GET', '/admin/audit-logs?page=$page&limit=$limit');
}