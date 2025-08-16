import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'database.dart';
import 'system.dart';
import 'package:geolocator/geolocator.dart';

class SellDatabase {
  late DbProvider dbProvider;

  SellDatabase() {
    dbProvider = new DbProvider();
  }

  Future<List<Map<String, dynamic>>> getUnsyncedSellReturns() async {
    final db = await DbProvider.db.database;
    return await db.query('sell_return', where: 'is_synced = 0');
  }

  // Update sync status by transaction_id with better error handling
  Future<void> updateSellReturnSyncStatusByTransactionId(int transactionId) async {
    final db = await dbProvider.database;
    try {
      await db.update(
        'sell_returns',
        {'is_synced': 1},
        where: 'transaction_id = ?',
        whereArgs: [transactionId],
      );
    } catch (e) {
      print('Error updating sell return sync status: $e');
      rethrow;
    }
  }

  // Update sync status by sell_id
  Future<void> updateSellReturnSyncStatusBySellId(int sellId) async {
    final db = await dbProvider.database;
    try {
      await db.update(
        'sell_return',
        {'is_synced': 1},
        where: 'sell_id = ?',
        whereArgs: [sellId],
      );
    } catch (e) {
      print('Error updating sell return sync status: $e');
      rethrow;
    }
  }

  Future<void> updateSellReturnSyncStatus(int transactionId) async {
    final db = await DbProvider.db.database;
    try {
      await db.update(
        'sell_return',
        {'is_synced': 1},
        where: 'transaction_id = ?',
        whereArgs: [transactionId],
      );
    } catch (e) {
      print('Error updating sell return sync status: $e');
      rethrow;
    }
  }

  // Enhanced return products method with better stock tracking
  Future<void> returnProducts(int sellId, List<Map<String, dynamic>> returnedProducts) async {
    final db = await DbProvider.db.database;

    print('Starting transaction for returning products');

    // Pre-load all product details before starting transaction
    final Map<int, Map<String, dynamic>> productDetailsCache = {};
    for (var product in returnedProducts) {
      try {
        final productId = product['product_id'];
        productDetailsCache[productId] = await getProductDetails(productId);
      } catch (e) {
        print('Error pre-loading product details: $e');
      }
    }

    await db.transaction((txn) async {
      try {
        // Update quantities in sell_lines
        for (var returnedProduct in returnedProducts) {
          print('Updating product: $returnedProduct');

          // Validate returned quantity doesn't exceed sold quantity
          var existingSellLine = await txn.query(
            'sell_lines',
            where: 'sell_id = ? AND product_id = ? AND variation_id = ?',
            whereArgs: [sellId, returnedProduct['product_id'], returnedProduct['variation_id']],
          );

          if (existingSellLine.isNotEmpty) {
            double existingQty = double.tryParse(existingSellLine.first['quantity'].toString()) ?? 0.0;
            double returnQty = double.tryParse(returnedProduct['quantity'].toString()) ?? 0.0;
            double newQty = existingQty - returnQty;

            if (newQty < 0) {
              throw Exception('Return quantity cannot exceed sold quantity');
            }

            await txn.update(
              'sell_lines',
              {'quantity': newQty},
              where: 'sell_id = ? AND product_id = ? AND variation_id = ?',
              whereArgs: [sellId, returnedProduct['product_id'], returnedProduct['variation_id']],
            );
          }
        }

        // Create formatted product list for sell_return table
        final List<Map<String, dynamic>> formattedProducts = [];
        for (var product in returnedProducts) {
          int productId = product['product_id'];
          var productDetails = productDetailsCache[productId] ?? {'name': 'Product #$productId'};

          formattedProducts.add({
            ...product,
            'unit_price_inc_tax': product['unit_price_inc_tax'] ?? product['unit_price'],
            'product_name': productDetails['name'] ?? 'Product #$productId',
          });
        }

        final sellDetails = await txn.query(
          'sell',
          where: 'id = ?',
          whereArgs: [sellId],
        );

        if (sellDetails.isEmpty) {
          throw Exception('Sell not found');
        }

        final transactionId = sellDetails.first['transaction_id'] ?? 0;
        String formattedDate = DateTime.now().toIso8601String().replaceAll('T', ' ').replaceAll('Z', '');

        print('Inserting sell return record');
        await txn.insert('sell_return', {
          'sell_id': sellId,
          'transaction_id': transactionId,
          'transaction_date': formattedDate,
          'invoice_no': 'RET-${DateTime.now().millisecondsSinceEpoch}',
          'discount_amount': 0.0,
          'discount_type': 'fixed',
          'products': jsonEncode(formattedProducts),
          'is_synced': 0,
        });

        print('Transaction completed successfully');
      } catch (e) {
        print('Error in return products transaction: $e');
        rethrow;
      }
    });
  }

  Future<Map<String, dynamic>> getSellById(int sellId) async {
    final db = await DbProvider.db.database;
    try {
      final result = await db.query(
        'sell',
        where: 'id = ?',
        whereArgs: [sellId],
      );

      if (result.isNotEmpty) {
        print(result.first);
        return result.first;
      } else {
        throw Exception('Sell not found');
      }
    } catch (e) {
      print('Error getting sell by ID: $e');
      rethrow;
    }
  }

  // Add item to cart with stock validation
  Future<int> store(value) async {
    final db = await dbProvider.database;
    try {
      var response = await db.insert('sell_lines', value);
      return response;
    } catch (e) {
      print('Error storing sell line: $e');
      rethrow;
    }
  }

  // Check presence of incomplete sellLine by variationId with better error handling
  checkSellLine(int varId, {sellId}) async {
    try {
      var where;
      (sellId == null) ? where = 'is_completed = ?' : where = 'sell_id = ?';
      var arg = (sellId == null) ? 0 : sellId;
      final db = await dbProvider.database;
      var response = await db.query('sell_lines',
          where: "$where and variation_id = ?", whereArgs: [arg, varId]);
      return response;
    } catch (e) {
      print('Error checking sell line: $e');
      return [];
    }
  }

  // Enhanced get products by sell ID with proper stock information
  Future<List<Map<String, dynamic>>> getProductsBySellId(int sellId) async {
    final db = await DbProvider.db.database;
    try {
      List<Map<String, dynamic>> result = await db.rawQuery('''
        SELECT sl.*, p.name as name, p.enable_stock, vld.qty_available
        FROM sell_lines sl
        LEFT JOIN products p ON sl.product_id = p.id
        LEFT JOIN variations_location_details vld ON sl.variation_id = vld.variation_id 
          AND sl.product_id = vld.product_id
        WHERE sl.sell_id = ?
      ''', [sellId]);

      return result;
    } catch (e) {
      print('Error getting products by sell ID: $e');
      return [];
    }
  }

  // Enhanced get sell return products with names
  Future<List<Map<String, dynamic>>> getSellReturnProductsWithNames(int sellReturnId) async {
    final db = await DbProvider.db.database;
    try {
      final sellReturn = await getSellReturnById(sellReturnId);

      if (sellReturn.isEmpty || sellReturn.first['products'] == null) {
        return [];
      }

      List<dynamic> productsData = jsonDecode(sellReturn.first['products']);
      List<Map<String, dynamic>> productsWithFullDetails = [];

      for (var product in productsData) {
        Map<String, dynamic> productMap = product is Map ?
        Map<String, dynamic>.from(product) :
        {'product_id': product};

        if (productMap['product_id'] != null) {
          Map<String, dynamic> productDetails = await getProductDetails(productMap['product_id']);
          productMap['product_name'] = productDetails['name'] ?? 'Unknown Product';
        }

        productsWithFullDetails.add(productMap);
      }

      return productsWithFullDetails;
    } catch (e) {
      print('Error getting sell return products with names: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getSellReturnDetails(int sellReturnId) async {
    final db = await DbProvider.db.database;
    try {
      return await db.rawQuery('''
        SELECT sr.*, p.name as product_name
        FROM sell_return sr
        LEFT JOIN products p ON sr.product_id = p.id
        WHERE sr.id = ?
      ''', [sellReturnId]);
    } catch (e) {
      print('Error getting sell return details: $e');
      return [];
    }
  }

  // Enhanced get sell lines with validation
  Future<List> getSellLines(sellId) async {
    final db = await DbProvider.db.database;
    try {
      var response = await db.query('sell_lines',
          columns: [
            'product_id',
            'variation_id',
            'quantity',
            'unit_price',
            'tax_rate_id',
            'discount_amount',
            'discount_type',
            'note'
          ],
          where: "sell_id = ?",
          whereArgs: [sellId]);
      return response;
    } catch (e) {
      print('Error getting sell lines: $e');
      return [];
    }
  }

  // Enhanced get incomplete lines with better stock calculation
  Future<List> getInCompleteLines(locationId, {sellId}) async {
    String where = 'is_completed = 0';
    if (sellId != null) where = 'sell_id = $sellId';

    String productLastSync = await System().getProductLastSync();

    final db = await dbProvider.database;
    try {
      // First check if products table exists
      List<Map<String, dynamic>> tables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='products'"
      );

      String query;
      if (tables.isNotEmpty) {
        // Products table exists, use full query
        query = '''SELECT DISTINCT SL.*, V.display_name AS name, V.sell_price_inc_tax,
             CASE 
               WHEN (qty_available IS NULL AND P.enable_stock = 0) THEN 9999 
               WHEN (qty_available IS NULL AND P.enable_stock = 1) THEN 0 
               ELSE MAX(0, qty_available - COALESCE((
                 SELECT SUM(SL2.quantity) FROM sell_lines AS SL2 
                 JOIN sell AS S on SL2.sell_id = S.id
                 WHERE (SL2.is_completed = 0 OR S.transaction_date > "$productLastSync") 
                   AND S.location_id = $locationId 
                   AND SL2.variation_id = V.variation_id
               ), 0))
             END as "stock_available"
             FROM "sell_lines" AS SL 
             JOIN "variations" AS V on (SL.variation_id = V.variation_id) 
             LEFT JOIN "variations_location_details" as VLD 
               ON SL.variation_id = VLD.variation_id 
               AND SL.product_id = VLD.product_id 
               AND VLD.location_id = $locationId
             LEFT JOIN "products" as P ON SL.product_id = P.id
             WHERE $where''';
      } else {
        // Products table doesn't exist, use simplified query
        query = '''SELECT DISTINCT SL.*, V.display_name AS name, V.sell_price_inc_tax,
             CASE 
               WHEN qty_available IS NULL THEN 9999 
               ELSE MAX(0, qty_available - COALESCE((
                 SELECT SUM(SL2.quantity) FROM sell_lines AS SL2 
                 JOIN sell AS S on SL2.sell_id = S.id
                 WHERE (SL2.is_completed = 0 OR S.transaction_date > "$productLastSync") 
                   AND S.location_id = $locationId 
                   AND SL2.variation_id = V.variation_id
               ), 0))
             END as "stock_available"
             FROM "sell_lines" AS SL 
             JOIN "variations" AS V on (SL.variation_id = V.variation_id) 
             LEFT JOIN "variations_location_details" as VLD 
               ON SL.variation_id = VLD.variation_id 
               AND SL.product_id = VLD.product_id 
               AND VLD.location_id = $locationId
             WHERE $where''';
      }

      List res = await db.rawQuery(query);
      return res;
    } catch (e) {
      print('Error getting incomplete lines: $e');
      return [];
    }
  }

  // Get sell lines with enhanced details
  Future<List> get({isCompleted, sellId}) async {
    String where;
    if (sellId != null) {
      where = 'sell_id = $sellId';
    } else {
      where = 'is_completed = $isCompleted';
    }
    final db = await dbProvider.database;
    try {
      List res = await db.rawQuery(
          '''SELECT DISTINCT SL.*,V.display_name as name,V.sell_price_inc_tax,V.sub_sku,
             V.default_sell_price FROM "sell_lines" as SL 
             JOIN "variations" as V on (SL.variation_id = V.variation_id) 
             WHERE $where''');
      return res;
    } catch (e) {
      print('Error getting sell lines: $e');
      return [];
    }
  }

  // Update sell_lines by variationId with validation
  Future<int> update(sellLineId, value) async {
    final db = await dbProvider.database;
    try {
      var response = await db.update('sell_lines', value, where: 'id = ?', whereArgs: [sellLineId]);
      return response;
    } catch (e) {
      print('Error updating sell line: $e');
      return 0;
    }
  }

  // Enhanced product details function with better error handling
  Future<Map<String, dynamic>> getProductDetails(int productId) async {
    final db = await dbProvider.database;

    try {
      List<Map<String, dynamic>> result = await db.query(
        'products',
        columns: ['id', 'name', 'sku', 'enable_stock'],
        where: 'id = ?',
        whereArgs: [productId],
      );

      if (result.isNotEmpty) {
        print('Product found: ${result.first}');
        return result.first;
      } else {
        print('Product not found in database: $productId');

        List<Map<String, dynamic>> variations = await db.query(
          'variations',
          columns: ['display_name'],
          where: 'product_id = ?',
          whereArgs: [productId],
        );

        if (variations.isNotEmpty && variations.first['display_name'] != null) {
          return {
            'id': productId,
            'name': variations.first['display_name'],
            'sku': null,
            'enable_stock': 1
          };
        }

        return {'id': productId, 'name': 'Product #$productId', 'sku': null, 'enable_stock': 1};
      }
    } catch (e) {
      print('Error getting product details: $e');
      return {'id': productId, 'name': 'Error Loading Product', 'sku': null, 'enable_stock': 1};
    }
  }

  // Update sell_lines after creating a sell
  Future<int> updateSellLine(value) async {
    final db = await dbProvider.database;
    try {
      var response = await db.update('sell_lines', value, where: 'is_completed = ?', whereArgs: [0]);
      return response;
    } catch (e) {
      print('Error updating sell line: $e');
      return 0;
    }
  }

  // Delete sell_line with stock adjustment
  Future<int> delete(int varId, int prodId, {sellId}) async {
    String where;
    var args;
    if (sellId == null) {
      where = 'is_completed = ? and variation_id = ? and product_id = ?';
      args = [0, varId, prodId];
    } else {
      where = 'sell_id = ? and variation_id = ? and product_id = ?';
      args = [sellId, varId, prodId];
    }
    final db = await dbProvider.database;
    try {
      var response = await db.delete('sell_lines', where: where, whereArgs: args);
      return response;
    } catch (e) {
      print('Error deleting sell line: $e');
      return 0;
    }
  }

  // Delete sell_line by sellId
  Future<int> deleteSellLineBySellId(sellId) async {
    final db = await dbProvider.database;
    try {
      var response = await db.delete('sell_lines', where: 'sell_id = ?', whereArgs: [sellId]);
      return response;
    } catch (e) {
      print('Error deleting sell line by sell ID: $e');
      return 0;
    }
  }

  // Create sell with validation
  Future<int> storeSell(Map<String, dynamic> value) async {
    final db = await dbProvider.database;
    try {
      var response = await db.insert('sell', value);
      return response;
    } catch (e) {
      print('Error storing sell: $e');
      rethrow;
    }
  }

  // Empty sells and sell details with confirmation
  deleteSellTables() async {
    final db = await dbProvider.database;
    try {
      await db.delete('sell');
      await db.delete('sell_lines');
      await db.delete('sell_payments');
    } catch (e) {
      print('Error deleting sell tables: $e');
      rethrow;
    }
  }

  // Enhanced get sells with better error handling
  Future<List> getSells({bool? all}) async {
    final db = await dbProvider.database;
    try {
      var response = (all == true)
          ? await db.query('sell', orderBy: 'id DESC')
          : await db.query('sell', orderBy: 'id DESC', where: 'is_quotation = ?', whereArgs: [0]);
      return response;
    } catch (e) {
      print('Error getting sells: $e');
      return [];
    }
  }

  // Get transaction IDs with validation
  Future<List> getTransactionIds() async {
    final db = await dbProvider.database;
    try {
      var response = await db.query('sell',
          columns: ['transaction_id'],
          where: 'transaction_id != ? AND transaction_id IS NOT NULL',
          whereArgs: ['null']);
      var ids = [];
      for (var element in response) {
        if (element['transaction_id'] != null) {
          ids.add(element['transaction_id']);
        }
      }
      return ids;
    } catch (e) {
      print('Error getting transaction IDs: $e');
      return [];
    }
  }

  // Get sales by sellId
  Future<List> getSellBySellId(sellId) async {
    final db = await dbProvider.database;
    try {
      var response = await db.query('sell', where: 'id = ?', whereArgs: [sellId]);
      return response;
    } catch (e) {
      print('Error getting sell by sell ID: $e');
      return [];
    }
  }

  // Get sales by TransactionId
  Future<List> getSellByTransactionId(transactionId) async {
    final db = await dbProvider.database;
    try {
      var response = await db.query('sell', where: 'transaction_id = ?', whereArgs: [transactionId]);
      return response;
    } catch (e) {
      print('Error getting sell by transaction ID: $e');
      return [];
    }
  }

  // Get not synced sales
  Future<List> getNotSyncedSells() async {
    final db = await dbProvider.database;
    try {
      var response = await db.query('sell', where: 'is_synced = 0');
      return response;
    } catch (e) {
      print('Error getting not synced sells: $e');
      return [];
    }
  }

  // Update sale with validation
  Future<int> updateSells(sellId, value) async {
    final db = await dbProvider.database;
    try {
      var response = await db.update('sell', value, where: 'id = ?', whereArgs: [sellId]);
      return response;
    } catch (e) {
      print('Error updating sells: $e');
      return 0;
    }
  }

  // Delete all incomplete lines
  Future<int> deleteInComplete() async {
    final db = await dbProvider.database;
    try {
      var response = await db.delete('sell_lines', where: 'is_completed = ?', whereArgs: [0]);
      return response;
    } catch (e) {
      print('Error deleting incomplete lines: $e');
      return 0;
    }
  }

  // Count sell lines
  Future<String> countSellLines({isCompleted, sellId}) async {
    String where;
    if (sellId != null) {
      where = 'sell_id = $sellId';
    } else {
      where = 'is_completed = 0';
    }

    final db = await dbProvider.database;
    try {
      var response = await db.rawQuery('SELECT COUNT(*) AS counts FROM sell_lines WHERE $where');
      return response[0]['counts'].toString();
    } catch (e) {
      print('Error counting sell lines: $e');
      return '0';
    }
  }

  // Delete a sell and corresponding sellLines from database with transaction
  deleteSell(int sellId) async {
    final db = await dbProvider.database;
    try {
      await db.transaction((txn) async {
        await txn.delete('sell', where: 'id = ?', whereArgs: [sellId]);
        await txn.delete('sell_lines', where: 'sell_id = ?', whereArgs: [sellId]);
        await txn.delete('sell_payments', where: 'sell_id = ?', whereArgs: [sellId]);
      });
    } catch (e) {
      print('Error deleting sell: $e');
      rethrow;
    }
  }

  // ================== Sell Return Methods ==================

  // Store sell return with validation
  Future<int> storeSellReturn(Map<String, dynamic> sellReturn) async {
    final db = await dbProvider.database;
    try {
      print('Inserting Sell Return: $sellReturn');
      var response = await db.insert('sell_return', sellReturn);
      print('Sell Return Inserted with ID: $response');
      return response;
    } catch (e) {
      print('Error storing sell return: $e');
      rethrow;
    }
  }

  Future<int> updateOrInsertSellReturn(Map<String, dynamic> sellReturn) async {
    final db = await dbProvider.database;
    try {
      List<Map<String, dynamic>> existingReturns = await db.query(
          'sell_returns',
          where: 'id = ?',
          whereArgs: [sellReturn['id']]
      );

      if (existingReturns.isNotEmpty) {
        return await db.update(
            'sell_returns',
            sellReturn,
            where: 'id = ?',
            whereArgs: [sellReturn['id']]
        );
      } else {
        return await db.insert(
            'sell_returns',
            sellReturn,
            conflictAlgorithm: ConflictAlgorithm.replace
        );
      }
    } catch (e) {
      print('Error updating or inserting sell return: $e');
      rethrow;
    }
  }

  Future<int> deleteSellReturn(int id) async {
    final db = await dbProvider.database;
    try {
      return await db.delete(
          'sell_returns',
          where: 'id = ?',
          whereArgs: [id]
      );
    } catch (e) {
      print('Error deleting sell return: $e');
      return 0;
    }
  }

  // Get sell returns with validation
  Future<List<Map<String, dynamic>>> getSellReturns() async {
    final db = await DbProvider.db.database;
    try {
      var result = await db.query('sell_return');
      print('Sell Returns from DB: $result');
      return result;
    } catch (e) {
      print('Error getting sell returns: $e');
      return [];
    }
  }

  // Get sell return by ID
  Future<List<Map<String, dynamic>>> getSellReturnById(int sellReturnId) async {
    final db = await DbProvider.db.database;
    try {
      return await db.query('sell_return', where: 'id = ?', whereArgs: [sellReturnId]);
    } catch (e) {
      print('Error getting sell return by ID: $e');
      return [];
    }
  }

  // Get not synced sell returns
  Future<List<Map<String, dynamic>>> getNotSyncedSellReturns() async {
    final db = await DbProvider.db.database;
    try {
      return await db.query('sell_return', where: 'is_synced = 0');
    } catch (e) {
      print('Error getting not synced sell returns: $e');
      return [];
    }
  }

  // Get sales by date range for daily sales card
  Future<List<Map<String, dynamic>>> getSalesByDateRange(String startDate, String endDate) async {
    final db = await DbProvider.db.database;
    try {
      // Query sales within the date range
      var result = await db.query(
        'sell',
        where: 'transaction_date >= ? AND transaction_date <= ? AND is_quotation = 0',
        whereArgs: [startDate, endDate],
        orderBy: 'transaction_date DESC',
      );
      return result;
    } catch (e) {
      print('Error getting sales by date range: $e');
      return [];
    }
  }

  // Get daily sales summary (count and total amount)
  Future<Map<String, dynamic>> getDailySalesSummary(String date) async {
    final db = await DbProvider.db.database;
    try {
      // Get sales count and total for the specific date
      var result = await db.rawQuery('''
        SELECT 
          COUNT(*) as sales_count,
          COALESCE(SUM(final_total), 0) as total_amount,
          COALESCE(SUM(total_before_tax), 0) as subtotal_amount
        FROM sell 
        WHERE DATE(transaction_date) = ? AND is_quotation = 0
      ''', [date]);

      if (result.isNotEmpty) {
        return {
          'sales_count': result.first['sales_count'] ?? 0,
          'total_amount': result.first['total_amount'] ?? 0.0,
          'subtotal_amount': result.first['subtotal_amount'] ?? 0.0,
        };
      }

      return {
        'sales_count': 0,
        'total_amount': 0.0,
        'subtotal_amount': 0.0,
      };
    } catch (e) {
      print('Error getting daily sales summary: $e');
      return {
        'sales_count': 0,
        'total_amount': 0.0,
        'subtotal_amount': 0.0,
      };
    }
  }

  // Get sales with pending payments
  Future<List<Map<String, dynamic>>> getPendingPaymentSales() async {
    final db = await DbProvider.db.database;
    try {
      // Query sales where payment is incomplete
      var result = await db.rawQuery('''
        SELECT s.*, 
               COALESCE(s.final_total, 0) as total_amount,
               COALESCE((
                 SELECT SUM(sp.amount) 
                 FROM sell_payments sp 
                 WHERE sp.sell_id = s.id
               ), 0) as paid_amount,
               COALESCE(s.final_total, 0) - COALESCE((
                 SELECT SUM(sp.amount) 
                 FROM sell_payments sp 
                 WHERE sp.sell_id = s.id
               ), 0) as pending_amount
        FROM sell s
        WHERE s.is_quotation = 0 
          AND (COALESCE(s.final_total, 0) - COALESCE((
                 SELECT SUM(sp.amount) 
                 FROM sell_payments sp 
                 WHERE sp.sell_id = s.id
               ), 0)) > 0
        ORDER BY s.transaction_date DESC
      ''');

      return result;
    } catch (e) {
      print('Error getting pending payment sales: $e');
      return [];
    }
  }
}