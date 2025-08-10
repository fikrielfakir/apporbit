import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:pos_final/api_end_points.dart';
import '../models/contact_model.dart';
import '../models/system.dart';
import 'api.dart';

class CustomerApi extends Api {
  var customers;

  get() async {
    String? url = ApiEndPoints.getContact;
    var token = await System().getToken();
    do {
      try {
        var response =
        await http.get(Uri.parse(url!), headers: this.getHeader('$token'));
        url = jsonDecode(response.body)['links']['next'];
        jsonDecode(response.body)['data'].forEach((element) {
          Contact().insertContact(Contact().contactModel(element));
        });
      } catch (e) {
        print('Delete contact error: $e');
        return null;
      }
    } while (url != null);
  }

  Future<dynamic> add(Map customer) async {
    try {
      String url = ApiEndPoints.addContact;
      var body = json.encode(customer);
      var token = await System().getToken();
      var response = await http.post(Uri.parse(url),
          headers: this.getHeader('$token'), body: body);
      var result = await jsonDecode(response.body);
      return result;
    } catch (e) {
      print('Delete contact error: $e');
      return null;
    }
  }

  Future<dynamic> update(Map customer, int contactId) async {
    try {
      String url = '${ApiEndPoints.updateContact}/$contactId';
      var body = json.encode(customer);
      var token = await System().getToken();
      var response = await http.put(Uri.parse(url),
          headers: this.getHeader('$token'), body: body);
      var result = await jsonDecode(response.body);
      return result;
    } catch (e) {
      print('Delete contact error: $e');
      return null;
    }
  }
  Future<Map<String, dynamic>> deleteContact(int contactId, {bool force = false}) async {
    try {
      final url = '${ApiEndPoints.deleteContact(contactId)}${force ? '?force=true' : ''}';
      debugPrint('Attempting to delete contact at U6RL: $url');

      final token = await System().getToken();
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token'
      };

      // First attempt to delete
      final response = await http.delete(
        Uri.parse(url),
        headers: headers,
      );

      // Handle successful response (200 OK)
      if (response.statusCode == 200) {
        debugPrint('Contact deleted successfully');
        return {
          'success': true,
          'message': 'Contact deleted successfully',
          'data': jsonDecode(response.body)
        };
      }

      // Handle 500 error (CrmUtil missing)
      if (response.statusCode == 500) {
        debugPrint('Received 500 error, verifying deletion status...');
        final verification = await _verifyContactDeletion(contactId);

        if (verification['success'] == true) {
          return {
            'success': true,
            'message': 'Contact deleted (verified after 500 error)',
            'verified': true
          };
        }

        return verification;
      }

      // Handle other error responses
      final errorData = jsonDecode(response.body);
      debugPrint('Delete failed with status ${response.statusCode}: ${errorData['message']}');

      return {
        'success': false,
        'message': errorData['message'] ?? 'Failed to delete contact',
        'error': errorData,
        'statusCode': response.statusCode
      };
    } catch (e) {
      debugPrint('Exception during contact deletion: $e');
      return {
        'success': false,
        'message': 'Network error occurred',
        'error': e.toString()
      };
    }
  }

  Future<Map<String, dynamic>> _verifyContactDeletion(int contactId) async {
    try {
      debugPrint('Verifying if contact $contactId was actually deleted...');
      final token = await System().getToken();
       final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token'
      };

      // Get single contact to verify
      final response = await http.get(
        Uri.parse('${ApiEndPoints.contact}/$contactId'),
        headers: headers,
      );

      if (response.statusCode == 404) {
        debugPrint('Contact not found - successfully deleted');
        return {
          'success': true,
          'message': 'Contact verified as deleted',
          'verified': true
        };
      }

      if (response.statusCode == 200) {
        debugPrint('Contact still exists - deletion failed');
        return {
          'success': false,
          'message': 'Contact still exists',
          'verified': true
        };
      }

      debugPrint('Verification failed with status ${response.statusCode}');
      return {
        'success': false,
        'message': 'Unable to verify deletion status',
        'statusCode': response.statusCode
      };
    } catch (e) {
      debugPrint('Verification error: $e');
      return {
        'success': false,
        'message': 'Verification failed: ${e.toString()}'
      };
    }
  }


Future<dynamic> getSingleContact(int contactId) async {
    try {
      String url = '${ApiEndPoints.getContact}/$contactId';
      var token = await System().getToken();
      var response = await http.get(
        Uri.parse(url),
        headers: this.getHeader('$token'),
      );
      var result = await jsonDecode(response.body);
      return result;
    } catch (e) {
      print('Delete contact error: $e');
      return null;
    }
  }
}