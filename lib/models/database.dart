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

  // Query to create system table (location, brand, category, taxRate)
  String createSystemTable =
      "CREATE TABLE system (id INTEGER PRIMARY KEY AUTOINCREMENT, keyId INTEGER DEFAULT null,"
      " key TEXT, value TEXT)";

  // Query to create contact table
  String createContactTable =
      "CREATE TABLE contact (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, city TEXT, state TEXT,"
      " country TEXT, address_line_1 TEXT, address_line_2 TEXT, zip_code TEXT, mobile TEXT)";

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
      " latitude REAL DEFAULT null, longitude REAL DEFAULT null)";

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
      "sell_id INTEGER DEFAULT 0"  // Add this line
      ")";
  // Get database of type Future<Database>
  Future<Database> get database async {
    // If database doesn't exist, create one
    if (_database == null) {
      _database = await initializeDatabase(Config.userId);
    }
    // If database exists, return database
    return _database!;
  }

  int currVersion = 9; // Increment the version due to the new table

  // Create tables during the creation of the database itself
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
                await db.execute(createSystemTable);
                await db.execute(createContactTable);
                await db.execute(createVariationTable);
                await db.execute(createVariationByLocationTable);
                await db.execute(createProductAvailableInLocationTable);
                await db.execute(createSellTable);
                await db.execute(createSellLineTable);
                await db.execute(createSellPaymentsTable);
                await db.execute(createSellReturnTable); // Ensure this line is present
              },
              onUpgrade: (db, oldVersion, newVersion) async {
                print("Upgrading database from version $oldVersion to $newVersion");
                if (oldVersion < 2) {
                  await db.execute("ALTER TABLE sell_lines RENAME TO prev_sell_line;");
                  await db.execute(createSellLineTable);
                  await db.execute("INSERT INTO sell_lines SELECT * FROM prev_sell_line;");
                }

                if (oldVersion < 3) {
                  await db.execute("ALTER TABLE variations RENAME  TO prev_variations;");
                  await db.execute(createVariationTable);
                  await db.execute("INSERT INTO variations SELECT * FROM prev_variations;");
                }

                if (oldVersion < 4) {
                  await db.execute(createContactTable);
                }

                if (oldVersion < 5) {
                  await db.execute("ALTER TABLE sell ADD COLUMN invoice_url TEXT DEFAULT null;");
                }

                if (oldVersion < 6) {
                  await db.execute("ALTER TABLE sell_payments ADD COLUMN account_id INTEGER DEFAULT null;");
                }

                if (oldVersion < 7) {
                  await db.execute("ALTER TABLE sell ADD COLUMN latitude REAL DEFAULT null;");
                  await db.execute("ALTER TABLE sell ADD COLUMN longitude REAL DEFAULT null;");
                }

                if (oldVersion < 8) {
                  await db.execute(createSellReturnTable); // Ensure this line is present
                }

                if (oldVersion < 9) {
                  await db.execute("ALTER TABLE sell_return ADD COLUMN sell_id INTEGER DEFAULT 0;");
                }

                db.setVersion(currVersion);
              },
            ));
      } else {
        return await openDatabase(
          path,
          version: currVersion,
          onCreate: (Database db, int version) async {
            print("Creating new database with version $version");
            await db.execute(createSystemTable);
            await db.execute(createContactTable);
            await db.execute(createVariationTable);
            await db.execute(createVariationByLocationTable);
            await db.execute(createProductAvailableInLocationTable);
            await db.execute(createSellTable);
            await db.execute(createSellLineTable);
            await db.execute(createSellPaymentsTable);
            await db.execute(createSellReturnTable); // Ensure this line is present
          },
          onUpgrade: (db, oldVersion, newVersion) async {
            print("Upgrading database from version $oldVersion to $newVersion");
            if (oldVersion < 2) {
              await db.execute("ALTER TABLE sell_lines RENAME TO prev_sell_line;");
              await db.execute(createSellLineTable);
              await db.execute("INSERT INTO sell_lines SELECT * FROM prev_sell_line;");
            }

            if (oldVersion < 3) {
              await db.execute("ALTER TABLE variations RENAME  TO prev_variations;");
              await db.execute(createVariationTable);
              await db.execute("INSERT INTO variations SELECT * FROM prev_variations;");
            }

            if (oldVersion < 4) {
              await db.execute(createContactTable);
            }

            if (oldVersion < 5) {
              await db.execute("ALTER TABLE sell ADD COLUMN invoice_url TEXT DEFAULT null;");
            }

            if (oldVersion < 6) {
              await db.execute("ALTER TABLE sell_payments ADD COLUMN account_id INTEGER DEFAULT null;");
            }

            if (oldVersion < 7) {
              await db.execute("ALTER TABLE sell ADD COLUMN latitude REAL DEFAULT null;");
              await db.execute("ALTER TABLE sell ADD COLUMN longitude REAL DEFAULT null;");
            }

            if (oldVersion < 8) {
              await db.execute(createSellReturnTable); // Ensure this line is present
            }

            if (oldVersion < 9) {
              await db.execute("ALTER TABLE sell_return ADD COLUMN sell_id INTEGER DEFAULT 0;");
            }

            db.setVersion(currVersion);
          },
        );
      }
    } catch (e) {
      print("Error initializing database: $e");
      rethrow; // Rethrow the error to handle it in the calling code
    }
  }
}