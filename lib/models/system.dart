import 'dart:convert';

import '../apis/system.dart';
import '../models/contact_model.dart';
import 'database.dart';

class System {
  late DbProvider dbProvider;

  System() {
    dbProvider = DbProvider();
  }

  // ----- DATABASE OPERATIONS -----

  /// Insert a key-value pair into the system table
  Future<int> insert(String key, dynamic value, [int? keyId]) async {
    final db = await dbProvider.database;
    var data = {
      'key': key,
      'keyId': keyId,
      'value': value,
    };
    return await db.insert('system', data);
  }

  /// Get a value from the system table by key
  Future<dynamic> get(String key, [int? keyId]) async {
    final db = await dbProvider.database;
    String where = keyId != null ? 'and keyId = $keyId' : '';
    List<Map<String, dynamic>> result =
    await db.query('system', where: 'key = ? $where', whereArgs: [key]);
    return (result.isNotEmpty) ? jsonDecode(result[0]['value']) : [];
  }

  /// Delete a specific key from the system table
  Future<int> delete(String colName) async {
    final db = await dbProvider.database;
    return await db.delete('system', where: 'key = ?', whereArgs: [colName]);
  }

  /// Empty the entire system table
  Future<int> empty() async {
    final db = await dbProvider.database;
    return await db.delete('system');
  }

  // ----- USER MANAGEMENT -----

  /// Save user details to the system table
  Future<int> insertUserDetails(Map userDetails) async {
    final db = await dbProvider.database;
    var data = {'key': 'loggedInUser', 'value': jsonEncode(userDetails)};
    return await db.insert('system', data);
  }

  /// Get the current logged-in user
  Future<Map<String, dynamic>> getCurrentUser() async {
    final db = await dbProvider.database;
    var result = await db.query('system', where: 'key = ?', whereArgs: ['loggedInUser']);

    if (result.isEmpty) {
      throw Exception('No user logged in');
    }

    return jsonDecode(result[0]['value'].toString());
  }

  /// Get the current user's ID
  Future<int> getCurrentUserId() async {
    try {
      final user = await getCurrentUser();
      final userId = int.parse(user['id'].toString());
      print('[DEBUG] Current User ID from DB: $userId'); // Debug log
      return userId;
    } catch (e) {
      print('[ERROR] Failed to get current user ID: $e');
      return 0; // Fallback value
    }
  }

  // ----- AUTHENTICATION -----

  /// Store authentication token
  Future<int> insertToken(String token) async {
    final db = await dbProvider.database;
    var data = {'key': 'token', 'value': token};
    return await db.insert('system', data);
  }

  /// Get stored authentication token
  Future<String> getToken() async {
    final db = await dbProvider.database;
    var result = await db.query('system', where: 'key = ?', whereArgs: ['token']);
    if (result.isEmpty) {
      throw Exception('No token found');
    }
    return result[0]['value'].toString();
  }

  // ----- PERMISSIONS -----

  /// Store user permissions
  Future<void> storePermissions() async {
    final db = await dbProvider.database;
    var result = await get('loggedInUser');
    if (result.containsKey('all_permissions')) {
      var userData = {
        'key': 'user_permissions',
        'value': jsonEncode(result['all_permissions'])
      };
      await db.insert('system', userData);
    }
  }

  /// Get user permissions
  Future<List> getPermission() async {
    var result = await get('loggedInUser');
    if (result.containsKey('is_admin') && result['is_admin'] == true) {
      return ['all'];
    } else {
      List permissions = await get('user_permissions');
      return permissions;
    }
  }

  /// Refresh the permission list
  Future<void> refreshPermissionList() async {
    final db = await dbProvider.database;
    await db.delete('system', where: 'key = ?', whereArgs: ['user_permissions']);
    await Permissions().get();
  }

  // ----- LOCATION MANAGEMENT -----

  /// Get the current location
  Future<Map<String, dynamic>?> getCurrentLocation() async {
    try {
      final db = await dbProvider.database;
      var result = await db.query('system', where: 'key = ?', whereArgs: ['current_location']);

      if (result.isNotEmpty) {
        return jsonDecode(result[0]['value'].toString());
      }

      // Fallback to first location if current not set
      final locations = await get('location');
      if (locations != null && locations.isNotEmpty) {
        return locations.first;
      }
      return null;
    } catch (e) {
      print('Error getting current location: $e');
      return null;
    }
  }

  /// Set the current location
  Future<void> setCurrentLocation(Map<String, dynamic> location) async {
    final db = await dbProvider.database;
    var existing = await db.query('system', where: 'key = ?', whereArgs: ['current_location']);

    if (existing.isNotEmpty) {
      await db.update(
        'system',
        {'value': jsonEncode(location)},
        where: 'key = ?',
        whereArgs: ['current_location'],
      );
    } else {
      await db.insert('system', {
        'key': 'current_location',
        'value': jsonEncode(location),
      });
    }
  }

  // ----- SYNC MANAGEMENT -----

  /// Insert or update product last sync datetime
  Future<void> insertProductLastSyncDateTimeNow() async {
    final db = await dbProvider.database;
    String? lastSync = await getProductLastSync();

    if (lastSync == null) {
      var data = {
        'key': 'product_last_sync',
        'value': DateTime.now().toString()
      };
      await db.insert('system', data);
    } else {
      await db.update('system', {'value': DateTime.now().toString()},
          where: 'key = ?', whereArgs: ['product_last_sync']);
    }
  }

  /// Get product last sync datetime
  Future<dynamic> getProductLastSync() async {
    final db = await dbProvider.database;
    var result = await db
        .query('system', where: 'key = ?', whereArgs: ['product_last_sync']);
    return (result.isNotEmpty) ? result[0]['value'] : null;
  }

  /// Manage call log last sync datetime
  Future<dynamic> callLogLastSyncDateTime([bool? insert]) async {
    final db = await dbProvider.database;
    var lastSyncDetail = await db
        .query('system', where: 'key = ?', whereArgs: ['call_logs_last_sync']);
    var lastSync =
    (lastSyncDetail.isNotEmpty) ? lastSyncDetail[0]['value'] : null;

    if (insert == true && lastSync == null) {
      await db.insert('system',
          {'key': 'call_logs_last_sync', 'value': DateTime.now().toString()});
    } else if (insert == true) {
      await db.update('system', {'value': DateTime.now().toString()},
          where: 'key = ?', whereArgs: ['call_logs_last_sync']);
    }

    return lastSync;
  }

  // ----- DATA RETRIEVAL METHODS -----

  /// Get categories list
  Future<List> getCategories() async {
    var categories = await get('taxonomy');
    return categories.isNotEmpty ? categories : [];
  }

  /// Get subcategories by parent ID
  Future<List> getSubCategories(int parentId) async {
    final db = await dbProvider.database;
    String where = 'and keyId = $parentId';
    var subCategories = await db.query('system',
        where: 'key = ? $where', whereArgs: ['sub_categories']);
    return subCategories.isNotEmpty ? subCategories : [];
  }

  /// Get brands list
  Future<List> getBrands() async {
    var brands = await get('brand');
    return brands.isNotEmpty ? brands : [];
  }

  /// Get payment accounts list
  Future<List> getPaymentAccounts() async {
    var accounts = await get('payment_accounts');
    return accounts.isNotEmpty ? accounts : [];
  }

  // ----- SYSTEM REFRESH -----

  /// Refresh all system data
  Future<void> refresh() async {
    final db = await dbProvider.database;
    List colNames = [
      'business',
      'user_permissions',
      'active-subscription',
      'payment_methods',
      'payment_method',
      'location',
      'tax',
      'brand',
      'taxonomy',
      'sub_categories',
      'payment_accounts'
    ];

    // Clear contacts
    await Contact().emptyContact();

    // Clear all listed system data
    for (var element in colNames) {
      await db.delete('system', where: 'key = ?', whereArgs: [element]);
    }

    // Reload system data
    await SystemApi().store();
  }
}