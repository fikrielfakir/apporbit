import 'dart:async';
import 'dart:io';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pos_final/config.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DbProvider {
  DbProvider();

  DbProvider._createInstance();

  static final DbProvider db = DbProvider._createInstance();
  static Database? _database;

  // Current database version (incremented to 12 to add last_name column)
  int currVersion = 13;

  // Query to create system table
  String createSystemTable =
      "CREATE TABLE system (id INTEGER PRIMARY KEY AUTOINCREMENT, keyId INTEGER DEFAULT null,"
      " key TEXT, value TEXT)";

  // Updated Query to create contact table with all required columns
  String createContactTable =
      "CREATE TABLE contact (id INTEGER PRIMARY KEY AUTOINCREMENT, "
      "first_name TEXT, "
      "last_name TEXT, "  // Added column
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
      "type TEXT)";

  // Query to create variation table
  String createVariationTable =
      "CREATE TABLE variations (id INTEGER PRIMARY KEY AUTOINCREMENT, product_id INTEGER,"
      " variation_id INTEGER, product_name TEXT, product_variation_name TEXT, variation_name TEXT,"
      " display_name TEXT, sku TEXT, sub_sku TEXT, type TEXT, enable_stock INTEGER,"
      " brand_id INTEGER, unit_id INTEGER, category_id INTEGER, sub_category_id INTEGER,"
      " tax_id INTEGER, default_sell_price REAL, sell_price_inc_tax REAL, product_image_url TEXT,"
      " selling_price_group BLOB DEFAULT null, product_description TEXT)";

  // Query to create variation by location table
  String createVariationByLocationTable =
      "CREATE TABLE variations_location_details (id INTEGER PRIMARY KEY AUTOINCREMENT,"
      " product_id INTEGER, variation_id INTEGER, location_id INTEGER, qty_available REAL)";

  // Query to create product available in location table
  String createProductAvailableInLocationTable =
      "CREATE TABLE product_locations (id INTEGER PRIMARY KEY AUTOINCREMENT, product_id INTEGER,"
      " location_id INTEGER)";

  // Query to create sale table in database
  String createSellTable =
      "CREATE TABLE sell (id INTEGER PRIMARY KEY AUTOINCREMENT, transaction_date TEXT, invoice_no TEXT,"
      " contact_id INTEGER, location_id INTEGER, status TEXT, tax_rate_id INTEGER, discount_amount REAL,"
      " discount_type TEXT, sale_note TEXT, staff_note TEXT, shipping_details TEXT, is_quotation INTEGER DEFAULT 0,"
      " shipping_charges REAL DEFAULT 0.00, invoice_amount REAL, change_return REAL DEFAULT 0.00, pending_amount REAL DEFAULT 0.00,"
      " is_synced INTEGER, transaction_id INTEGER DEFAULT null, invoice_url TEXT DEFAULT null,"
      " latitude REAL DEFAULT null, longitude REAL DEFAULT null, return_amount REAL DEFAULT 0.00)";

  // Query to create sale line table in database
  String createSellLineTable =
      "CREATE TABLE sell_lines (id INTEGER PRIMARY KEY AUTOINCREMENT, sell_id INTEGER,"
      " product_id INTEGER, variation_id INTEGER, quantity REAL, unit_price REAL,"
      " tax_rate_id INTEGER, discount_amount REAL, discount_type TEXT, note TEXT,"
      " is_completed INTEGER)";

  // Query to create payment line table in database
  String createSellPaymentsTable =
      "CREATE TABLE sell_payments (id INTEGER PRIMARY KEY AUTOINCREMENT, sell_id INTEGER,"
      " payment_id INTEGER DEFAULT null, method TEXT, amount REAL, note TEXT,"
      " account_id INTEGER DEFAULT null, is_return INTEGER DEFAULT 0)";

  // Query to create sell return table
  String createSellReturnTable =
      "CREATE TABLE sell_return ("
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
      ")";

  // Get database of type Future<Database>
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
              onCreate: (db, version) async {
                print("Creating new database with version $version");
                await _createTables(db);
              },
              onUpgrade: (db, oldVersion, newVersion) async {
                print("Upgrading database from version $oldVersion to $newVersion");
                await _upgradeTables(db, oldVersion, newVersion);
              },
            ));
      } else {
        return await openDatabase(
          path,
          version: currVersion,
          onCreate: (Database db, int version) async {
            print("Creating new database with version $version");
            await _createTables(db);
          },
          onUpgrade: (db, oldVersion, newVersion) async {
            print("Upgrading database from version $oldVersion to $newVersion");
            await _upgradeTables(db, oldVersion, newVersion);
          },
        );
      }
    } catch (e) {
      print("Error initializing database: $e");
      rethrow;
    }
  }

  // Create tables for the database
  _createTables(Database db) async {
    await db.execute(
        'CREATE TABLE IF NOT EXISTS attendance (id INTEGER PRIMARY KEY, user_id INTEGER, location_id INTEGER, clock_in_time TEXT, clock_out_time TEXT, work_hours INTEGER, is_synced INTEGER DEFAULT 0)');

    // Offline cache tables
    await db.execute(
        'CREATE TABLE IF NOT EXISTS cached_products (id INTEGER PRIMARY KEY, product_data TEXT, cached_at INTEGER)');

    await db.execute(
        'CREATE TABLE IF NOT EXISTS cached_contacts (id INTEGER PRIMARY KEY, contact_data TEXT, cached_at INTEGER)');

    await db.execute(
        'CREATE TABLE IF NOT EXISTS cached_sales (id INTEGER PRIMARY KEY, sale_data TEXT, cached_at INTEGER)');

    await db.execute(
        'CREATE TABLE IF NOT EXISTS cached_all_sales (id INTEGER PRIMARY KEY, sale_data TEXT, cached_at INTEGER)');

    await db.execute(
        'CREATE TABLE IF NOT EXISTS offline_queue (id INTEGER PRIMARY KEY AUTOINCREMENT, action_type TEXT, action_data TEXT, created_at INTEGER, synced INTEGER DEFAULT 0)');

    // Original table creations
    await db.execute(createSystemTable);
    await db.execute(createContactTable);
    await db.execute(createVariationTable);
    await db.execute(createVariationByLocationTable);
    await db.execute(createProductAvailableInLocationTable);
    await db.execute(createSellTable);
    await db.execute(createSellLineTable);
    await db.execute(createSellPaymentsTable);
    await db.execute(createSellReturnTable);
  }

  // Upgrade tables in the database
  _upgradeTables(Database db, int oldVersion, int newVersion) async {
    // Migration for version 1 to 2
    if (oldVersion < 2) {
      await db.execute("ALTER TABLE sell_lines RENAME TO prev_sell_line;");
      await db.execute(createSellLineTable);
      await db.execute("INSERT INTO sell_lines SELECT * FROM prev_sell_line;");
    }

    // Migration for version 2 to 3
    if (oldVersion < 3) {
      await db.execute("ALTER TABLE variations RENAME TO prev_variations;");
      await db.execute(createVariationTable);
      await db.execute("INSERT INTO variations SELECT * FROM prev_variations;");
    }

    // Migration for version 3 to 4
    if (oldVersion < 4) {
      await db.execute(createContactTable);
    }

    // Migration for version 4 to 5
    if (oldVersion < 5) {
      await db.execute("ALTER TABLE sell ADD COLUMN invoice_url TEXT DEFAULT null;");
    }

    // Migration for version 5 to 6
    if (oldVersion < 6) {
      await db.execute("ALTER TABLE sell_payments ADD COLUMN account_id INTEGER DEFAULT null;");
    }

    // Migration for version 6 to 7
    if (oldVersion < 7) {
      await db.execute("ALTER TABLE sell ADD COLUMN latitude REAL DEFAULT null;");
      await db.execute("ALTER TABLE sell ADD COLUMN longitude REAL DEFAULT null;");
    }

    // Migration for version 7 to 8
    if (oldVersion < 8) {
      await db.execute(createSellReturnTable);
    }

    // Migration for version 8 to 9
    if (oldVersion < 9) {
      await db.execute("ALTER TABLE sell_return ADD COLUMN sell_id INTEGER DEFAULT 0;");
    }

    // Migration for version 9 to 10
    if (oldVersion < 10) {
      await db.execute("ALTER TABLE sell ADD COLUMN return_amount REAL DEFAULT 0.00;");
    }

    // Migration for version 10 to 11
    if (oldVersion < 11) {
      await db.execute("ALTER TABLE contact ADD COLUMN first_name TEXT;");
      await db.execute("ALTER TABLE contact ADD COLUMN type TEXT;");
    }

    // Migration for version 11 to 12 (adding last_name column)
    if (oldVersion < 12) {
      await db.execute("ALTER TABLE contact ADD COLUMN last_name TEXT;");
    }
    // Migration for version 12 to 13 (adding refrige_num column)
    if (oldVersion < 13) {
      await db.execute("ALTER TABLE contact ADD COLUMN refrige_num TEXT;");
    }

    db.setVersion(newVersion);
  }

  // Helper method to close the database
  Future close() async {
    final db = await database;
    db.close();
  }
}