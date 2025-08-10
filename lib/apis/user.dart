import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:pos_final/api_end_points.dart';

import 'api.dart';

class User extends Api {
  Future<Map> get(var token) async {
    String url = ApiEndPoints.getUser;
    var response =
    await http.get(Uri.parse(url), headers: this.getHeader(token));
    var userDetails = jsonDecode(response.body);
    Map userDetailsMap = userDetails['data'];
    return userDetailsMap;
  }

  // Add method to change password
  Future<Map<String, dynamic>> changePassword({
    required String token,
    required String currentPassword,
    required String newPassword,
  }) async {
    final url = ApiEndPoints.updatePasswordUrl;

    final body = {
      'current_password': currentPassword,
      'new_password': newPassword,
    };

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: getHeader(token),
        body: jsonEncode(body),
      );

      final jsonResponse = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': jsonResponse['msg'] ?? 'Password updated successfully'
        };
      } else {
        return {
          'success': false,
          'error': jsonResponse['error'] ?? 'Failed to update password'
        };
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // Add method for forgot password
  Future<Map<String, dynamic>> forgotPassword({
    required String token,
    required String email,
  }) async {
    final url = ApiEndPoints.forgotPasswordUrl;

    final body = {
      'email': email,
    };

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: getHeader(token),
        body: jsonEncode(body),
      );

      final jsonResponse = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': jsonResponse['msg'] ?? 'Password reset email sent successfully'
        };
      } else {
        return {
          'success': false,
          'error': jsonResponse['error'] ?? 'Failed to send password reset email'
        };
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
}