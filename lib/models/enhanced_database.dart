// lib/models/enhanced_database.dart
import 'dart:async';
import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pos_final/config.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class EnhancedDbProvider {
  EnhancedDbProvider._createInstance();
  static final EnhancedDbProvider db = EnhancedDbProvider._createInstance();
  static Database? _database;

  // Incremented version for offline optimizations
  int currVersion = 15;

  // Enhanced system table with sync tracking
  String createSystemTable =
      "CREATE TABLE system (id INTEGER PRIMARY KEY AUTOINCREMENT, keyId INTEGER DEFAULT null,"
      " key TEXT, value TEXT, last_sync TEXT DEFAULT null, sync_status INTEGER DEFAULT 0)";

  // Enhanced contact table with offline sync fields
  String createContactTable =
      "CREATE TABLE contact (id INTEGER PRIMARY KEY AUTOINCREMENT, "
      "server_id INTEGER DEFAULT null, " // Track server ID separately
      "first_name TEXT, "
      "last_name TEXT, "
      "name TEXT, "
      "supplier_business_name TEXT, "
      "prefix TEXT, "
      "middle_name TEXT, "
      "email TEXT, "
      "contact_id TEXT, "
      "contact_status TEXT, "
      "tax_number TEXT, "
      "city TEXT, "
      "state TEXT, "
      "country TEXT, "
      "refrige_num TEXT, "
      "address_line_1 TEXT, "
      "address_line_2 TEXT, "
      "zip_code TEXT, "
      "dob TEXT, "
      "mobile TEXT, "
      "landline TEXT, "
      "alternate_number TEXT, "
      "pay_term_number TEXT, "
      "pay_term_type TEXT, "
      "credit_limit REAL, "
      "created_by INTEGER, "
      "balance REAL, "
      "total_rp INTEGER, "
      "total_rp_used INTEGER, "
      "total_rp_expired INTEGER, "
      "is_default INTEGER, "
      "shipping_address TEXT, "
      "position TEXT, "
      "customer_group_id INTEGER, "
      "crm_source TEXT, "
      "crm_life_stage TEXT, "
      "custom_field1 TEXT, "
      "custom_field2 TEXT, "
      "custom_field3 TEXT, "
      "custom_field4 TEXT, "
      "deleted_at TEXT, "
      "created_at TEXT, "
      "updated_at TEXT, "
      "type TEXT, "
      "is_synced INTEGER DEFAULT 1, " // Track sync status
      "needs_sync INTEGER DEFAULT 0, " // Mark for sync
      "last_sync_at TEXT DEFAULT null)";

  // Enhanced variations table with better offline support
  String createVariationTable =
      "CREATE TABLE variations (id INTEGER PRIMARY KEY AUTOINCREMENT, product_id INTEGER,"
      " variation_id INTEGER, product_name TEXT, product_variation_name TEXT, variation_name TEXT,"
      " display_name TEXT, sku TEXT, sub_sku TEXT, type TEXT, enable_stock INTEGER,"
      " brand_id INTEGER, unit_id INTEGER, category_id INTEGER, sub_category_id INTEGER,"
      " tax_id INTEGER, default_sell_price REAL, sell_price_inc_tax REAL, product_image_url TEXT,"
      " selling_price_group BLOB DEFAULT null, product_description TEXT, "
      " last_sync_at TEXT DEFAULT null, is_active INTEGER DEFAULT 1)";

  // Enhanced sell table with better offline tracking
  String createSellTable =
      "CREATE TABLE sell (id INTEGER PRIMARY KEY AUTOINCREMENT, transaction_date TEXT, invoice_no TEXT,"
      " contact_id INTEGER, location_id INTEGER, status TEXT, tax_rate_id INTEGER, discount_amount REAL,"
      " discount_type TEXT, sale_note TEXT, staff_note TEXT, shipping_details TEXT, is_quotation INTEGER DEFAULT 0,"
      " shipping_charges REAL DEFAULT 0.00, invoice_amount REAL, change_return REAL DEFAULT 0.00, pending_amount REAL DEFAULT 0.00,"
      " is_synced INTEGER DEFAULT 0, transaction_id INTEGER DEFAULT null, invoice_url TEXT DEFAULT null,"
      " latitude REAL DEFAULT null, longitude REAL DEFAULT null, return_amount REAL DEFAULT 0.00, "
      " created_offline INTEGER DEFAULT 0, sync_attempts INTEGER DEFAULT 0, last_sync_attempt TEXT DEFAULT null, "
      " created_at_local TEXT DEFAULT CURRENT_TIMESTAMP, sync_error TEXT DEFAULT null)";

  // Stock movement tracking table for better offline inventory management
  String createStockMovementTable =
      "CREATE TABLE stock_movements ("
      "id INTEGER PRIMARY KEY AUTOINCREMENT, "
      "product_id INTEGER NOT NULL, "
      "variation_id INTEGER NOT NULL, "
      "location_id INTEGER NOT NULL, "
      "movement_type TEXT NOT NULL, " // 'sale', 'return', 'transfer_out', 'transfer_in', 'adjustment'
      "quantity REAL NOT NULL, "
      "reference_id INTEGER, " // sell_id, return_id, transfer_id etc.
      "reference_type TEXT, " // 'sell', 'return', 'transfer'
      "created_at TEXT DEFAULT CURRENT_TIMESTAMP, "
      "is_synced INTEGER DEFAULT 0, "
      "notes TEXT)";

  // Offline queue table for API calls
  String createOfflineQueueTable =
      "CREATE TABLE offline_queue ("
      "id INTEGER PRIMARY KEY AUTOINCREMENT, "
      "endpoint TEXT NOT NULL, "
      "method TEXT NOT NULL, " // GET, POST, PUT, DELETE
      "data TEXT, " // JSON data
      "priority INTEGER DEFAULT 0, " // Higher number = higher priority
      "max_retries INTEGER DEFAULT 3, "
      "retry_count INTEGER DEFAULT 0, "
      "status TEXT DEFAULT 'pending', " // pending, processing, completed, failed
      "created_at TEXT DEFAULT CURRENT_TIMESTAMP, "
      "last_attempt TEXT, "
      "error_message TEXT, "
      "depends_on INTEGER DEFAULT null)"; // For dependent API calls

  // App settings table for offline configuration
  String createAppSettingsTable =
      "CREATE TABLE app_settings ("
      "id INTEGER PRIMARY KEY AUTOINCREMENT, "
      "setting_key TEXT UNIQUE NOT NULL, "
      "setting_value TEXT, "
      "data_type TEXT DEFAULT 'string', " // string, integer, boolean, json
      "is_synced INTEGER DEFAULT 1, "
      "updated_at TEXT DEFAULT CURRENT_TIMESTAMP)";

  Future<Database> get database async {
    if (_database == null) {
      _database = await initializeDatabase(Config.userId);
    }
    return _database!;
  }

  Future<Database> initializeDatabase(loginUserId) async {
    Directory posDirectory = await getApplicationDocumentsDirectory();
    String path = join(posDirectory.path + 'PosDemo$loginUserId.db');

    try {
      if (Platform.isWindows || Platform.isLinux) {
        return await databaseFactoryFfi.openDatabase(path,
            options: OpenDatabaseOptions(
              version: currVersion,
              onCreate: _onCreate,
              onUpgrade: _onUpgrade,
            ));
      } else {
        return await openDatabase(
          path,
          version: currVersion,
          onCreate: _onCreate,
          onUpgrade: _onUpgrade,
        );
      }
    } catch (e) {
      print("Error initializing database: $e");
      rethrow;
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    print("Creating new database with version $version");

    // Create all tables
    await db.execute(createSystemTable);
    await db.execute(createContactTable);
    await db.execute(createVariationTable);
    await db.execute("CREATE TABLE variations_location_details (id INTEGER PRIMARY KEY AUTOINCREMENT,"
        " product_id INTEGER, variation_id INTEGER, location_id INTEGER, qty_available REAL)");
    await db.execute("CREATE TABLE product_locations (id INTEGER PRIMARY KEY AUTOINCREMENT, product_id INTEGER,"
        " location_id INTEGER)");
    await db.execute(createSellTable);
    await db.execute("CREATE TABLE sell_lines (id INTEGER PRIMARY KEY AUTOINCREMENT, sell_id INTEGER,"
        " product_id INTEGER, variation_id INTEGER, quantity REAL, unit_price REAL,"
        " tax_rate_id INTEGER, discount_amount REAL, discount_type TEXT, note TEXT,"
        " is_completed INTEGER)");
    await db.execute("CREATE TABLE sell_payments (id INTEGER PRIMARY KEY AUTOINCREMENT, sell_id INTEGER,"
        " payment_id INTEGER DEFAULT null, method TEXT, amount REAL, note TEXT,"
        " account_id INTEGER DEFAULT null, is_return INTEGER DEFAULT 0)");
    await db.execute("CREATE TABLE sell_return ("
        "id INTEGER PRIMARY KEY AUTOINCREMENT, "
        "transaction_id INTEGER, "
        "transaction_date TEXT, "
        "invoice_no TEXT, "
        "discount_amount REAL, "
        "discount_type TEXT, "
        "products TEXT, "
        "is_synced INTEGER DEFAULT 0, "
        "created_at TEXT DEFAULT CURRENT_TIMESTAMP, "
        "sell_id INTEGER DEFAULT 0"
        ")");
    await db.execute(createStockMovementTable);
    await db.execute(createOfflineQueueTable);
    await db.execute(createAppSettingsTable);

    // Insert default settings
    await _insertDefaultSettings(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    print("Upgrading database from version $oldVersion to $newVersion");

    // Handle existing migrations first (versions 1-13)
    await _handleExistingMigrations(db, oldVersion);

    // New migrations for offline support
    if (oldVersion < 14) {
      // Add offline tracking fields to existing tables
      await _addOfflineFields(db);
    }

    if (oldVersion < 15) {
      // Add new offline tables
      await _addOfflineTables(db);
    }
  }

  Future<void> _handleExistingMigrations(Database db, int oldVersion) async {
    // Include all your existing migration logic here
    if (oldVersion < 2) {
      await db.execute("ALTER TABLE sell_lines RENAME TO prev_sell_line;");
      await db.execute("CREATE TABLE sell_lines (id INTEGER PRIMARY KEY AUTOINCREMENT, sell_id INTEGER,"
          " product_id INTEGER, variation_id INTEGER, quantity REAL, unit_price REAL,"
          " tax_rate_id INTEGER, discount_amount REAL, discount_type TEXT, note TEXT,"
          " is_completed INTEGER)");
      await db.execute("INSERT INTO sell_lines SELECT * FROM prev_sell_line;");
    }

    if (oldVersion < 13) {
      try {
        await db.execute("ALTER TABLE contact ADD COLUMN refrige_num TEXT;");
      } catch (e) {
        // Column might already exist
      }
    }
  }

  Future<void> _addOfflineFields(Database db) async {
    try {
      // Add offline fields to contact table
      await db.execute("ALTER TABLE contact ADD COLUMN server_id INTEGER DEFAULT null;");
      await db.execute("ALTER TABLE contact ADD COLUMN is_synced INTEGER DEFAULT 1;");
      await db.execute("ALTER TABLE contact ADD COLUMN needs_sync INTEGER DEFAULT 0;");
      await db.execute("ALTER TABLE contact ADD COLUMN last_sync_at TEXT DEFAULT null;");

      // Add offline fields to sell table
      await db.execute("ALTER TABLE sell ADD COLUMN created_offline INTEGER DEFAULT 0;");
      await db.execute("ALTER TABLE sell ADD COLUMN sync_attempts INTEGER DEFAULT 0;");
      await db.execute("ALTER TABLE sell ADD COLUMN last_sync_attempt TEXT DEFAULT null;");
      await db.execute("ALTER TABLE sell ADD COLUMN created_at_local TEXT DEFAULT CURRENT_TIMESTAMP;");
      await db.execute("ALTER TABLE sell ADD COLUMN sync_error TEXT DEFAULT null;");

      // Add offline fields to variations table
      await db.execute("ALTER TABLE variations ADD COLUMN last_sync_at TEXT DEFAULT null;");
      await db.execute("ALTER TABLE variations ADD COLUMN is_active INTEGER DEFAULT 1;");

      // Add sync tracking to system table
      await db.execute("ALTER TABLE system ADD COLUMN last_sync TEXT DEFAULT null;");
      await db.execute("ALTER TABLE system ADD COLUMN sync_status INTEGER DEFAULT 0;");

    } catch (e) {
      print("Error adding offline fields: $e");
      // Some fields might already exist, continue
    }
  }

  Future<void> _addOfflineTables(Database db) async {
    try {
      await db.execute(createStockMovementTable);
      await db.execute(createOfflineQueueTable);
      await db.execute(createAppSettingsTable);
      await _insertDefaultSettings(db);
    } catch (e) {
      print("Error adding offline tables: $e");
    }
  }

  Future<void> _insertDefaultSettings(Database db) async {
    final defaultSettings = [
      {'setting_key': 'offline_mode_enabled', 'setting_value': 'true', 'data_type': 'boolean'},
      {'setting_key': 'auto_sync_enabled', 'setting_value': 'true', 'data_type': 'boolean'},
      {'setting_key': 'sync_interval_minutes', 'setting_value': '15', 'data_type': 'integer'},
      {'setting_key': 'max_offline_days', 'setting_value': '7', 'data_type': 'integer'},
      {'setting_key': 'last_full_sync', 'setting_value': '', 'data_type': 'string'},
      {'setting_key': 'offline_storage_limit_mb', 'setting_value': '100', 'data_type': 'integer'},
    ];

    for (var setting in defaultSettings) {
      try {
        await db.insert('app_settings', setting);
      } catch (e) {
        // Setting might already exist, update it
        await db.update(
          'app_settings',
          setting,
          where: 'setting_key = ?',
          whereArgs: [setting['setting_key']],
        );
      }
    }
  }

  // Helper methods for offline queue management
  Future<void> addToOfflineQueue({
    required String endpoint,
    required String method,
    String? data,
    int priority = 0,
    int? dependsOn,
  }) async {
    final db = await database;
    await db.insert('offline_queue', {
      'endpoint': endpoint,
      'method': method,
      'data': data,
      'priority': priority,
      'depends_on': dependsOn,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getPendingOfflineQueue() async {
    final db = await database;
    return await db.query(
      'offline_queue',
      where: 'status = ? AND retry_count < max_retries',
      whereArgs: ['pending'],
      orderBy: 'priority DESC, created_at ASC',
    );
  }

  Future<void> updateQueueItemStatus(int id, String status, {String? error}) async {
    final db = await database;
    await db.update(
      'offline_queue',
      {
        'status': status,
        'last_attempt': DateTime.now().toIso8601String(),
        'error_message': error,
        if (status == 'processing') 'retry_count': 'retry_count + 1',
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Stock movement tracking
  Future<void> recordStockMovement({
    required int productId,
    required int variationId,
    required int locationId,
    required String movementType,
    required double quantity,
    int? referenceId,
    String? referenceType,
    String? notes,
  }) async {
    final db = await database;
    await db.insert('stock_movements', {
      'product_id': productId,
      'variation_id': variationId,
      'location_id': locationId,
      'movement_type': movementType,
      'quantity': quantity,
      'reference_id': referenceId,
      'reference_type': referenceType,
      'notes': notes,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  // App settings management
  Future<String?> getSetting(String key) async {
    final db = await database;
    final result = await db.query(
      'app_settings',
      where: 'setting_key = ?',
      whereArgs: [key],
    );
    return result.isNotEmpty ? result.first['setting_value']?.toString() : null;
  }

  Future<void> setSetting(String key, String value, {String dataType = 'string'}) async {
    final db = await database;
    await db.insert(
      'app_settings',
      {
        'setting_key': key,
        'setting_value': value,
        'data_type': dataType,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future close() async {
    final db = await database;
    db.close();
  }
}