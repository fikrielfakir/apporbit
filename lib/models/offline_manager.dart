
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database.dart';
import 'system.dart';

class OfflineManager {
  static final OfflineManager _instance = OfflineManager._internal();
  factory OfflineManager() => _instance;
  OfflineManager._internal();

  Database? _database;
  bool _isOfflineMode = false;

  Future<void> initialize() async {
    _database = await DbProvider.db.database;
    await _checkOfflineMode();
  }

  Future<void> _checkOfflineMode() async {
    final prefs = await SharedPreferences.getInstance();
    _isOfflineMode = prefs.getBool('offline_mode') ?? false;
  }

  bool get isOfflineMode => _isOfflineMode;

  Future<void> setOfflineMode(bool offline) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('offline_mode', offline);
    _isOfflineMode = offline;
  }

  // Cache products for offline use
  Future<void> cacheProducts(List<Map<String, dynamic>> products) async {
    final batch = _database!.batch();

    // Clear existing cached products
    batch.delete('cached_products');

    // Insert new products
    for (var product in products) {
      batch.insert('cached_products', {
        'id': product['id'],
        'product_data': jsonEncode(product),
        'cached_at': DateTime.now().millisecondsSinceEpoch,
      });
    }

    await batch.commit();
  }

  // Get cached products
  Future<List<Map<String, dynamic>>> getCachedProducts({
    String? searchTerm,
    int? categoryId,
    int? brandId,
    bool? inStock,
  }) async {
    String whereClause = '1=1';
    List<dynamic> whereArgs = [];

    final result = await _database!.query('cached_products');

    List<Map<String, dynamic>> products = result.map((row) {
      return jsonDecode(row['product_data'] as String) as Map<String, dynamic>;
    }).toList();

    // Apply filters
    if (searchTerm != null && searchTerm.isNotEmpty) {
      products = products.where((product) =>
          product['display_name'].toString().toLowerCase().contains(searchTerm.toLowerCase())
      ).toList();
    }

    if (categoryId != null && categoryId != 0) {
      products = products.where((product) =>
      product['category_id'] == categoryId
      ).toList();
    }

    if (brandId != null && brandId != 0) {
      products = products.where((product) =>
      product['brand_id'] == brandId
      ).toList();
    }

    if (inStock == true) {
      products = products.where((product) =>
      (product['enable_stock'] != 0) ? product['stock_available'] > 0 : true
      ).toList();
    }

    return products;
  }

  // Cache contacts for offline use
  Future<void> cacheContacts(List<Map<String, dynamic>> contacts) async {
    final batch = _database!.batch();

    batch.delete('cached_contacts');

    for (var contact in contacts) {
      batch.insert('cached_contacts', {
        'id': contact['id'],
        'contact_data': jsonEncode(contact),
        'cached_at': DateTime.now().millisecondsSinceEpoch,
      });
    }

    await batch.commit();
  }

  // Get cached contacts
  Future<List<Map<String, dynamic>>> getCachedContacts({String? searchTerm}) async {
    final result = await _database!.query('cached_contacts');

    List<Map<String, dynamic>> contacts = result.map((row) {
      return jsonDecode(row['contact_data'] as String) as Map<String, dynamic>;
    }).toList();

    if (searchTerm != null && searchTerm.isNotEmpty) {
      contacts = contacts.where((contact) =>
      contact['name'].toString().toLowerCase().contains(searchTerm.toLowerCase()) ||
          contact['mobile'].toString().contains(searchTerm)
      ).toList();
    }

    return contacts;
  }

  // Cache sales for offline use (Recent Sales)
  Future<void> cacheSales(List<Map<String, dynamic>> sales) async {
    final batch = _database!.batch();

    batch.delete('cached_sales');

    for (var sale in sales) {
      batch.insert('cached_sales', {
        'id': sale['id'],
        'sale_data': jsonEncode(sale),
        'cached_at': DateTime.now().millisecondsSinceEpoch,
      });
    }

    await batch.commit();
  }

  // Get cached sales (Recent Sales)
  Future<List<Map<String, dynamic>>> getCachedSales() async {
    final result = await _database!.query('cached_sales');

    return result.map((row) {
      return jsonDecode(row['sale_data'] as String) as Map<String, dynamic>;
    }).toList();
  }

  // Cache all sales for offline use (All Sales Tab)
  Future<void> cacheAllSales(List<Map<String, dynamic>> allSales) async {
    final batch = _database!.batch();

    batch.delete('cached_all_sales');

    for (var sale in allSales) {
      batch.insert('cached_all_sales', {
        'id': sale['id'],
        'sale_data': jsonEncode(sale),
        'cached_at': DateTime.now().millisecondsSinceEpoch,
      });
    }

    await batch.commit();
  }

  // Get cached all sales (All Sales Tab)
  Future<List<Map<String, dynamic>>> getCachedAllSales() async {
    final result = await _database!.query('cached_all_sales');

    return result.map((row) {
      return jsonDecode(row['sale_data'] as String) as Map<String, dynamic>;
    }).toList();
  }

  // Queue offline actions for later sync
  Future<void> queueOfflineAction(String actionType, Map<String, dynamic> data) async {
    await _database!.insert('offline_queue', {
      'action_type': actionType,
      'action_data': jsonEncode(data),
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'synced': 0,
    });
  }

  // Get queued actions
  Future<List<Map<String, dynamic>>> getQueuedActions() async {
    return await _database!.query('offline_queue', where: 'synced = ?', whereArgs: [0]);
  }

  // Mark action as synced
  Future<void> markActionSynced(int id) async {
    await _database!.update('offline_queue',
        {'synced': 1},
        where: 'id = ?',
        whereArgs: [id]
    );
  }

  // Check if any cached data exists
  Future<bool> hasCachedData() async {
    try {
      final cachedSales = await _database!.query('cached_sales');
      final cachedAllSales = await _database!.query('cached_all_sales');
      final cachedProducts = await _database!.query('cached_products');
      final cachedContacts = await _database!.query('cached_contacts');

      return cachedSales.isNotEmpty ||
          cachedAllSales.isNotEmpty ||
          cachedProducts.isNotEmpty ||
          cachedContacts.isNotEmpty;
    } catch (e) {
      print('Error checking cached data: $e');
      return false;
    }
  }

  // Get cached data summary
  Future<Map<String, int>> getCachedDataSummary() async {
    try {
      final cachedSales = await _database!.query('cached_sales');
      final cachedAllSales = await _database!.query('cached_all_sales');
      final cachedProducts = await _database!.query('cached_products');
      final cachedContacts = await _database!.query('cached_contacts');

      return {
        'sales': cachedSales.length,
        'all_sales': cachedAllSales.length,
        'products': cachedProducts.length,
        'contacts': cachedContacts.length,
      };
    } catch (e) {
      print('Error getting cached data summary: $e');
      return {};
    }
  }

  // Sync queued actions when online
  Future<void> syncQueuedActions() async {
    if (_isOfflineMode) return;

    final actions = await getQueuedActions();

    for (var action in actions) {
      try {
        // Process each action based on type
        await _processQueuedAction(action);
        await markActionSynced(action['id']);
      } catch (e) {
        print('Error syncing action ${action['id']}: $e');
      }
    }
  }

  Future<void> _processQueuedAction(Map<String, dynamic> action) async {
    final actionType = action['action_type'];
    final actionData = jsonDecode(action['action_data']);

    switch (actionType) {
      case 'create_sale':
      // Process sale creation
        break;
      case 'update_contact':
      // Process contact update
        break;
      case 'create_stock_transfer':
      // Process stock transfer creation
        break;
    }
  }
}
