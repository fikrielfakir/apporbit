import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pos_final/api_end_points.dart';
import '../config.dart';
import '../pages/login/login_screen.dart';

class Api {
  final String baseUrl = Config.baseUrl;
  final String apiUrl = ApiEndPoints.apiUrl;
  final String clientId = Config().clientId;
  final String clientSecret = Config().clientSecret;

  // Global navigator key to access navigation from anywhere
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Authenticates a user with the provided credentials
  /// Returns a map with success status and either token or error message
  Future<Map<String, dynamic>> login(String username, String password) async {
    final url = ApiEndPoints.loginUrl;

    final body = {
      'grant_type': 'password',
      'client_id': clientId,
      'client_secret': clientSecret,
      'username': username,
      'password': password,
    };

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: body,
      );

      final jsonResponse = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'access_token': jsonResponse['access_token']};
      } else if (response.statusCode == 401) {
        return {'success': false, 'error': jsonResponse['error']};
      } else {
        return {'success': false, 'error': 'Unknown error: ${response.statusCode}'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Creates HTTP headers with authorization token
  Map<String, String> getHeader(String? token) {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Makes authenticated API requests with automatic redirection to login when not authenticated
  Future<Map<String, dynamic>> authenticatedRequest({
    required String endpoint,
    required String method,
    String? token,
    Map<String, dynamic>? body,
  }) async {
    // If no token is provided, redirect to login immediately
    if (token == null || token.isEmpty) {
      _redirectToLogin();
      return {'success': false, 'error': 'Not authenticated'};
    }

    Uri url = Uri.parse(endpoint);
    http.Response response;

    try {
      switch (method.toUpperCase()) {
        case 'GET':
          response = await http.get(url, headers: getHeader(token));
          break;
        case 'POST':
          response = await http.post(url,
            headers: getHeader(token),
            body: body != null ? jsonEncode(body) : null,
          );
          break;
        case 'PUT':
          response = await http.put(url,
            headers: getHeader(token),
            body: body != null ? jsonEncode(body) : null,
          );
          break;
        case 'DELETE':
          response = await http.delete(url, headers: getHeader(token));
          break;
        default:
          return {'success': false, 'error': 'Invalid method'};
      }

      // Handle authentication errors
      if (response.statusCode == 401) {
        _redirectToLogin();
        return {'success': false, 'error': 'Authentication failed'};
      }

      // Parse response
      final jsonResponse = jsonDecode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {'success': true, 'data': jsonResponse};
      } else {
        return {'success': false, 'error': jsonResponse['message'] ?? 'Request failed'};
      }

    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Redirects to login screen
  void _redirectToLogin() {
    // Use the navigator key to navigate to login screen
    navigatorKey.currentState?.pushNamedAndRemoveUntil(
      '/login',
          (route) => false, // Clear all routes in stack
    );
  }
}