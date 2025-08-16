
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
  static const int CACHE_EXPIRY_HOURS = 24; // Cache expires after 24 hours

  Future<void> initialize() async {
    _database = await DbProvider.db.database;
    await _checkOfflineMode();
    await _createCacheTables();
  }

  Future<void> _createCacheTables() async {
    if (_database == null) return;
    
    try {
      // Create cache tables if they don't exist
      await _database!.execute('''
        CREATE TABLE IF NOT EXISTS cached_sales (
          id INTEGER,
          sale_data TEXT NOT NULL,
          cached_at INTEGER NOT NULL,
          PRIMARY KEY (id)
        )
      ''');

      await _database!.execute('''
        CREATE TABLE IF NOT EXISTS cached_all_sales (
          id INTEGER,
          sale_data TEXT NOT NULL,
          cached_at INTEGER NOT NULL,
          PRIMARY KEY (id)
        )
      ''');

      await _database!.execute('''
        CREATE TABLE IF NOT EXISTS cached_products (
          id INTEGER,
          product_data TEXT NOT NULL,
          cached_at INTEGER NOT NULL,
          PRIMARY KEY (id)
        )
      ''');

      await _database!.execute('''
        CREATE TABLE IF NOT EXISTS cached_contacts (
          id INTEGER,
          contact_data TEXT NOT NULL,
          cached_at INTEGER NOT NULL,
          PRIMARY KEY (id)
        )
      ''');

      await _database!.execute('''
        CREATE TABLE IF NOT EXISTS offline_queue (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          action_type TEXT NOT NULL,
          action_data TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          synced INTEGER DEFAULT 0
        )
      ''');
    } catch (e) {
      print('Error creating cache tables: $e');
    }
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

  // Check if cached data is still valid
  bool _isCacheValid(int cachedAt) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final cacheAge = now - cachedAt;
    final maxAge = CACHE_EXPIRY_HOURS * 60 * 60 * 1000; // Convert to milliseconds
    return cacheAge < maxAge;
  }

  // Cache products for offline use with better error handling
  Future<void> cacheProducts(List<Map<String, dynamic>> products) async {
    if (_database == null || products.isEmpty) return;

    try {
      final batch = _database!.batch();
      final currentTime = DateTime.now().millisecondsSinceEpoch;

      // Use INSERT OR REPLACE to handle duplicates
      for (var product in products) {
        batch.rawInsert('''
          INSERT OR REPLACE INTO cached_products (id, product_data, cached_at) 
          VALUES (?, ?, ?)
        ''', [product['id'], jsonEncode(product), currentTime]);
      }

      await batch.commit(noResult: true);
      print('Cached ${products.length} products successfully');
    } catch (e) {
      print('Error caching products: $e');
    }
  }

  // Get cached products with validity check
  Future<List<Map<String, dynamic>>> getCachedProducts({
    String? searchTerm,
    int? categoryId,
    int? brandId,
    bool? inStock,
    bool forceExpired = false,
  }) async {
    if (_database == null) return [];

    try {
      final result = await _database!.query('cached_products');
      
      if (result.isEmpty) {
        print('No cached products found');
        return [];
      }

      List<Map<String, dynamic>> products = [];

      for (var row in result) {
        final cachedAt = row['cached_at'] as int;
        
        // Check cache validity unless forced to use expired cache
        if (!forceExpired && !_isCacheValid(cachedAt)) {
          print('Cache expired for product ${row['id']}');
          continue;
        }

        try {
          final product = jsonDecode(row['product_data'] as String) as Map<String, dynamic>;
          products.add(product);
        } catch (e) {
          print('Error decoding cached product ${row['id']}: $e');
        }
      }

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

      print('Retrieved ${products.length} valid cached products');
      return products;
    } catch (e) {
      print('Error retrieving cached products: $e');
      return [];
    }
  }

  // Cache sales for offline use (Recent Sales) - IMPROVED
  Future<void> cacheSales(List<Map<String, dynamic>> sales) async {
    if (_database == null || sales.isEmpty) return;

    try {
      final batch = _database!.batch();
      final currentTime = DateTime.now().millisecondsSinceEpoch;

      // Use INSERT OR REPLACE to handle duplicates
      for (var sale in sales) {
        batch.rawInsert('''
          INSERT OR REPLACE INTO cached_sales (id, sale_data, cached_at) 
          VALUES (?, ?, ?)
        ''', [sale['id'], jsonEncode(sale), currentTime]);
      }

      await batch.commit(noResult: true);
      print('Cached ${sales.length} sales successfully');
    } catch (e) {
      print('Error caching sales: $e');
    }
  }

  // Get cached sales (Recent Sales) - IMPROVED
  Future<List<Map<String, dynamic>>> getCachedSales({bool forceExpired = false}) async {
    if (_database == null) return [];

    try {
      final result = await _database!.query(
        'cached_sales', 
        orderBy: 'cached_at DESC'
      );

      if (result.isEmpty) {
        print('No cached sales found');
        return [];
      }

      List<Map<String, dynamic>> sales = [];

      for (var row in result) {
        final cachedAt = row['cached_at'] as int;
        
        // Check cache validity unless forced to use expired cache
        if (!forceExpired && !_isCacheValid(cachedAt)) {
          print('Cache expired for sale ${row['id']}');
          continue;
        }

        try {
          final sale = jsonDecode(row['sale_data'] as String) as Map<String, dynamic>;
          sales.add(sale);
        } catch (e) {
          print('Error decoding cached sale ${row['id']}: $e');
        }
      }

      print('Retrieved ${sales.length} valid cached sales');
      return sales;
    } catch (e) {
      print('Error retrieving cached sales: $e');
      return [];
    }
  }

  // Cache all sales for offline use (All Sales Tab) - IMPROVED
  Future<void> cacheAllSales(List<Map<String, dynamic>> allSales) async {
    if (_database == null || allSales.isEmpty) return;

    try {
      final batch = _database!.batch();
      final currentTime = DateTime.now().millisecondsSinceEpoch;

      // Use INSERT OR REPLACE to handle duplicates
      for (var sale in allSales) {
        batch.rawInsert('''
          INSERT OR REPLACE INTO cached_all_sales (id, sale_data, cached_at) 
          VALUES (?, ?, ?)
        ''', [sale['id'], jsonEncode(sale), currentTime]);
      }

      await batch.commit(noResult: true);
      print('Cached ${allSales.length} all sales successfully');
    } catch (e) {
      print('Error caching all sales: $e');
    }
  }

  // Get cached all sales (All Sales Tab) - IMPROVED
  Future<List<Map<String, dynamic>>> getCachedAllSales({bool forceExpired = false}) async {
    if (_database == null) return [];

    try {
      final result = await _database!.query(
        'cached_all_sales', 
        orderBy: 'cached_at DESC'
      );

      if (result.isEmpty) {
        print('No cached all sales found');
        return [];
      }

      List<Map<String, dynamic>> allSales = [];

      for (var row in result) {
        final cachedAt = row['cached_at'] as int;
        
        // Check cache validity unless forced to use expired cache
        if (!forceExpired && !_isCacheValid(cachedAt)) {
          print('Cache expired for all sale ${row['id']}');
          continue;
        }

        try {
          final sale = jsonDecode(row['sale_data'] as String) as Map<String, dynamic>;
          allSales.add(sale);
        } catch (e) {
          print('Error decoding cached all sale ${row['id']}: $e');
        }
      }

      print('Retrieved ${allSales.length} valid cached all sales');
      return allSales;
    } catch (e) {
      print('Error retrieving cached all sales: $e');
      return [];
    }
  }

  // Cache contacts for offline use - IMPROVED
  Future<void> cacheContacts(List<Map<String, dynamic>> contacts) async {
    if (_database == null || contacts.isEmpty) return;

    try {
      final batch = _database!.batch();
      final currentTime = DateTime.now().millisecondsSinceEpoch;

      // Use INSERT OR REPLACE to handle duplicates
      for (var contact in contacts) {
        batch.rawInsert('''
          INSERT OR REPLACE INTO cached_contacts (id, contact_data, cached_at) 
          VALUES (?, ?, ?)
        ''', [contact['id'], jsonEncode(contact), currentTime]);
      }

      await batch.commit(noResult: true);
      print('Cached ${contacts.length} contacts successfully');
    } catch (e) {
      print('Error caching contacts: $e');
    }
  }

  // Get cached contacts - IMPROVED
  Future<List<Map<String, dynamic>>> getCachedContacts({
    String? searchTerm,
    bool forceExpired = false
  }) async {
    if (_database == null) return [];

    try {
      final result = await _database!.query('cached_contacts');

      if (result.isEmpty) {
        print('No cached contacts found');
        return [];
      }

      List<Map<String, dynamic>> contacts = [];

      for (var row in result) {
        final cachedAt = row['cached_at'] as int;
        
        // Check cache validity unless forced to use expired cache
        if (!forceExpired && !_isCacheValid(cachedAt)) {
          print('Cache expired for contact ${row['id']}');
          continue;
        }

        try {
          final contact = jsonDecode(row['contact_data'] as String) as Map<String, dynamic>;
          contacts.add(contact);
        } catch (e) {
          print('Error decoding cached contact ${row['id']}: $e');
        }
      }

      // Apply search filter
      if (searchTerm != null && searchTerm.isNotEmpty) {
        contacts = contacts.where((contact) =>
        contact['name'].toString().toLowerCase().contains(searchTerm.toLowerCase()) ||
            contact['mobile'].toString().contains(searchTerm)
        ).toList();
      }

      print('Retrieved ${contacts.length} valid cached contacts');
      return contacts;
    } catch (e) {
      print('Error retrieving cached contacts: $e');
      return [];
    }
  }

  // Queue offline actions for later sync
  Future<void> queueOfflineAction(String actionType, Map<String, dynamic> data) async {
    if (_database == null) return;

    try {
      await _database!.insert('offline_queue', {
        'action_type': actionType,
        'action_data': jsonEncode(data),
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'synced': 0,
      });
      print('Queued offline action: $actionType');
    } catch (e) {
      print('Error queuing offline action: $e');
    }
  }

  // Get queued actions
  Future<List<Map<String, dynamic>>> getQueuedActions() async {
    if (_database == null) return [];

    try {
      return await _database!.query('offline_queue', where: 'synced = ?', whereArgs: [0]);
    } catch (e) {
      print('Error getting queued actions: $e');
      return [];
    }
  }

  // Mark action as synced
  Future<void> markActionSynced(int id) async {
    if (_database == null) return;

    try {
      await _database!.update('offline_queue',
          {'synced': 1},
          where: 'id = ?',
          whereArgs: [id]
      );
    } catch (e) {
      print('Error marking action as synced: $e');
    }
  }

  // Check if any cached data exists - IMPROVED
  Future<bool> hasCachedData() async {
    if (_database == null) return false;

    try {
      final cachedSales = await _database!.query('cached_sales', limit: 1);
      final cachedAllSales = await _database!.query('cached_all_sales', limit: 1);
      final cachedProducts = await _database!.query('cached_products', limit: 1);
      final cachedContacts = await _database!.query('cached_contacts', limit: 1);

      return cachedSales.isNotEmpty ||
          cachedAllSales.isNotEmpty ||
          cachedProducts.isNotEmpty ||
          cachedContacts.isNotEmpty;
    } catch (e) {
      print('Error checking cached data: $e');
      return false;
    }
  }

  // Get cached data summary - IMPROVED
  Future<Map<String, int>> getCachedDataSummary() async {
    if (_database == null) return {};

    try {
      final cachedSales = await _database!.rawQuery('SELECT COUNT(*) as count FROM cached_sales');
      final cachedAllSales = await _database!.rawQuery('SELECT COUNT(*) as count FROM cached_all_sales');
      final cachedProducts = await _database!.rawQuery('SELECT COUNT(*) as count FROM cached_products');
      final cachedContacts = await _database!.rawQuery('SELECT COUNT(*) as count FROM cached_contacts');

      return {
        'sales': cachedSales[0]['count'] as int,
        'all_sales': cachedAllSales[0]['count'] as int,
        'products': cachedProducts[0]['count'] as int,
        'contacts': cachedContacts[0]['count'] as int,
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

  // Clear expired cache entries
  Future<void> clearExpiredCache() async {
    if (_database == null) return;

    try {
      final cutoffTime = DateTime.now().millisecondsSinceEpoch - (CACHE_EXPIRY_HOURS * 60 * 60 * 1000);
      
      await _database!.delete('cached_sales', where: 'cached_at < ?', whereArgs: [cutoffTime]);
      await _database!.delete('cached_all_sales', where: 'cached_at < ?', whereArgs: [cutoffTime]);
      await _database!.delete('cached_products', where: 'cached_at < ?', whereArgs: [cutoffTime]);
      await _database!.delete('cached_contacts', where: 'cached_at < ?', whereArgs: [cutoffTime]);
      
      print('Cleared expired cache entries');
    } catch (e) {
      print('Error clearing expired cache: $e');
    }
  }

  // Force clear all cache
  Future<void> clearAllCache() async {
    if (_database == null) return;

    try {
      await _database!.delete('cached_sales');
      await _database!.delete('cached_all_sales');
      await _database!.delete('cached_products');
      await _database!.delete('cached_contacts');
      
      print('Cleared all cache');
    } catch (e) {
      print('Error clearing all cache: $e');
    }
  }
}
