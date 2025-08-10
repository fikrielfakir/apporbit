import 'package:flutter/material.dart';
import '../apis/api.dart';

class LocationProvider with ChangeNotifier {
  final Api _api;
  final String? token;
  List<Map<String, dynamic>> _locations = [];
  bool _isLoading = false;
  String? _error;

  LocationProvider(this._api, {this.token});

  List<Map<String, dynamic>> get locations => _locations;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadLocations() async {
    if (token == null) {
      _error = 'Not authenticated';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.authenticatedRequest(
        endpoint: '${_api.apiUrl}/business-locations',
        method: 'GET',
        token: token,
      );

      if (response['success']) {
        _locations = List<Map<String, dynamic>>.from(response['data']['data']);
      } else {
        _error = response['error'];
      }
    } catch (e) {
      print('Error loading locations: $e');
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}