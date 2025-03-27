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

  // Update sync status by transaction_id
  Future<void> updateSellReturnSyncStatusByTransactionId(int transactionId) async {
    final db = await dbProvider.database;
    await db.update(
      'sell_returns', // Update the 'sell_returns' table
      {'is_synced': 1},
      where: 'transaction_id = ?',
      whereArgs: [transactionId],
    );
  }

  // Update sync status by sell_id
  Future<void> updateSellReturnSyncStatusBySellId(int sellId) async {
    final db = await dbProvider.database;
    await db.update(
      'sell_return', // Update the 'sell_return' table
      {'is_synced': 1},
      where: 'sell_id = ?',
      whereArgs: [sellId],
    );
  }

  Future<void> updateSellReturnSyncStatus(int transactionId) async {
    final db = await DbProvider.db.database;
    await db.update(
      'sell_return',
      {'is_synced': 1},
      where: 'transaction_id = ?',
      whereArgs: [transactionId],
    );
  }


// In SellDatabase.dart, modify the returnProducts method:
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
      for (var returnedProduct in returnedProducts) {
        print('Updating product: $returnedProduct');
        await txn.update(
          'sell_lines',
          {'quantity': returnedProduct['quantity']},
          where: 'sell_id = ? AND product_id = ? AND variation_id = ?',
          whereArgs: [sellId, returnedProduct['product_id'], returnedProduct['variation_id']],
        );
      }

      // Create formatted product list
      final List<Map<String, dynamic>> formattedProducts = [];
      for (var product in returnedProducts) {
        int productId = product['product_id'];
        var productDetails = productDetailsCache[productId] ??
            {'name': 'Product #$productId'};

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

      // Format the date in the correct format
      String formattedDate = DateTime.now().toIso8601String().replaceAll('T', ' ').replaceAll('Z', '');

      print('Inserting sell return record');
      await txn.insert('sell_return', {
        'sell_id': sellId,
        'transaction_id': transactionId,
        'transaction_date': formattedDate, // Use the correctly formatted date
        'invoice_no': 'RET-${DateTime.now().millisecondsSinceEpoch}',
        'discount_amount': 0.0,
        'discount_type': 'fixed',
        'products': jsonEncode(formattedProducts),
        'is_synced': 0,
      });
    });

    print('Transaction completed successfully');
  }
  Future<Map<String, dynamic>> getSellById(int sellId) async {
    final db = await DbProvider.db.database;
    final result = await db.query(
      'sell',
      where: 'id = ?',
      whereArgs: [sellId],
    );

    if (result.isNotEmpty) {
      print(result.first); // Print sell details for verification
      return result.first;
    } else {
      throw Exception('Sell not found');
    }
  }

  // Add item to cart
  Future<int> store(value) async {
    final db = await dbProvider.database;
    var response = db.insert('sell_lines', value);
    return response;
  }

  // Check presence of incomplete sellLine by variationId
  checkSellLine(int varId, {sellId}) async {
    var where;
    (sellId == null) ? where = 'is_completed = ?' : where = 'sell_id = ?';
    var arg = (sellId == null) ? 0 : sellId;
    final db = await dbProvider.database;
    var response = await db.query('sell_lines',
        where: "$where and variation_id = ?", whereArgs: [arg, varId]);
    return response;
  }

  Future<List<Map<String, dynamic>>> getProductsBySellId(int sellId) async {
    final db = await dbProvider.database;

    // استخدام JOIN للحصول على أسماء المنتجات مع بيانات المبيعات
    List<Map<String, dynamic>> result = await db.rawQuery('''
    SELECT sl.*, p.name as name
    FROM sell_lines sl
    LEFT JOIN products p ON sl.product_id = p.id
    WHERE sl.sell_id = ?
  ''', [sellId]);

    return result;
  }

  // NEW METHOD: Get sell return products with detailed product information
  Future<List<Map<String, dynamic>>> getSellReturnProductsWithNames(int sellReturnId) async {
    final db = await dbProvider.database;
    final sellReturn = await getSellReturnById(sellReturnId);

    if (sellReturn.isEmpty || sellReturn.first['products'] == null) {
      return [];
    }

    List<dynamic> productsData = jsonDecode(sellReturn.first['products']);
    List<Map<String, dynamic>> productsWithFullDetails = [];

    for (var product in productsData) {
      // If product is not already a Map, convert it
      Map<String, dynamic> productMap = product is Map ?
      Map<String, dynamic>.from(product) :
      {'product_id': product};

      // Get product details if we have product_id
      if (productMap['product_id'] != null) {
        Map<String, dynamic> productDetails = await getProductDetails(productMap['product_id']);
        productMap['product_name'] = productDetails['name'] ?? 'Unknown Product';
      }

      productsWithFullDetails.add(productMap);
    }

    return productsWithFullDetails;
  }

  Future<List<Map<String, dynamic>>> getSellReturnDetails(int sellReturnId) async {
    final db = await dbProvider.database;
    return await db.rawQuery('''
    SELECT sr.*, p.name as product_name
    FROM sell_return sr
    LEFT JOIN products p ON sr.product_id = p.id
    WHERE sr.id = ?
  ''', [sellReturnId]);
  }

  // Fetch sell_lines by sell_id
  Future<List> getSellLines(sellId) async {
    final db = await dbProvider.database;
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
  }

  // Fetch incomplete sellLine
  Future<List> getInCompleteLines(locationId, {sellId}) async {
    String where = 'is_completed = 0';
    if (sellId != null) where = 'sell_id = $sellId';

    // Get product last sync datetime
    String productLastSync = await System().getProductLastSync();

    final db = await dbProvider.database;
    List res = await db.rawQuery(
        'SELECT DISTINCT SL.*, V.display_name AS name, V.sell_price_inc_tax,'
            ' CASE WHEN (qty_available IS NULL AND enable_stock = 0) THEN 9999 '
            ' WHEN (qty_available IS NULL AND enable_stock = 1) THEN 0 '
            ' ELSE (qty_available - COALESCE('
            ' (SELECT SUM(SL2.quantity) FROM sell_lines AS SL2 JOIN sell AS S on SL2.sell_id = S.id'
            ' WHERE (SL2.is_completed = 0 OR S.transaction_date > "$productLastSync") AND S.location_id = $locationId AND SL2.variation_id=V.variation_id)'
            ', 0))'
            ' END as "stock_available" '
            ' FROM "sell_lines" AS SL JOIN "variations" AS V on (SL.variation_id = V.variation_id) '
            ' LEFT JOIN "variations_location_details" as VLD '
            'ON SL.variation_id = VLD.variation_id AND SL.product_id = VLD.product_id AND VLD.location_id = $locationId '
            'where $where');
    return res;
  }

  // Fetch incomplete sellLine
  Future<List> get({isCompleted, sellId}) async {
    String where;
    if (sellId != null) {
      where = 'sell_id = $sellId';
    } else {
      where = 'is_completed = $isCompleted';
    }
    final db = await dbProvider.database;
    List res = await db.rawQuery(
        'SELECT DISTINCT SL.*,V.display_name as name,V.sell_price_inc_tax,V.sub_sku,'
            'V.default_sell_price FROM "sell_lines" as SL JOIN "variations" as V '
            'on (SL.variation_id = V.variation_id) '
            'where $where');
    return res;
  }

  // Update sell_lines by variationId
  Future<int> update(sellLineId, value) async {
    final db = await dbProvider.database;
    var response = await db
        .update('sell_lines', value, where: 'id = ?', whereArgs: [sellLineId]);
    return response;
  }

  // Enhanced product details function with better error handling
  Future<Map<String, dynamic>> getProductDetails(int productId) async {
    final db = await dbProvider.database;

    try {
      List<Map<String, dynamic>> result = await db.query(
        'products',
        columns: ['id', 'name', 'sku'],
        where: 'id = ?',
        whereArgs: [productId],
      );

      if (result.isNotEmpty) {
        print('Product found: ${result.first}');
        return result.first;
      } else {
        print('Product not found in database: $productId');

        // Try to get name from variations table as fallback
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
            'sku': null
          };
        }

        return {'id': productId, 'name': 'Product #$productId', 'sku': null};
      }
    } catch (e) {
      print('Error getting product details: $e');
      return {'id': productId, 'name': 'Error Loading Product', 'sku': null};
    }
  }

  // Update sell_lines after creating a sell
  Future<int> updateSellLine(value) async {
    final db = await dbProvider.database;
    var response = await db
        .update('sell_lines', value, where: 'is_completed = ?', whereArgs: [0]);
    return response;
  }

  // Delete sell_line
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
    var response = await db.delete('sell_lines', where: where, whereArgs: args);
    return response;
  }

  // Delete sell_line by sellId
  Future<int> deleteSellLineBySellId(sellId) async {
    final db = await dbProvider.database;
    var response = await db
        .delete('sell_lines', where: 'sell_id = ?', whereArgs: [sellId]);
    return response;
  }

  // Create sell
  Future<int> storeSell(Map<String, dynamic> value) async {
    final db = await dbProvider.database;
    var response = await db.insert('sell', value);
    return response;
  }

  // Empty sells and sell details
  deleteSellTables() async {
    final db = await dbProvider.database;
    await db.delete('sell');
    await db.delete('sell_lines');
    await db.delete('sell_payments');
  }

  // Fetch current sales from database
  Future<List> getSells({bool? all}) async {
    final db = await dbProvider.database;
    var response = (all == true)
        ? await db.query('sell', orderBy: 'id DESC')
        : await db.query('sell',
        orderBy: 'id DESC', where: 'is_quotation = ?', whereArgs: [0]);
    return response;
  }

  // Fetch transactionIds of synced sales from sell table
  Future<List> getTransactionIds() async {
    final db = await dbProvider.database;
    var response = await db.query('sell',
        columns: ['transaction_id'],
        where: 'transaction_id != ?',
        whereArgs: ['null']);
    var ids = [];
    response.forEach((element) {
      ids.add(element['transaction_id']);
    });
    return ids;
  }

  // Fetch sales by sellId
  Future<List> getSellBySellId(sellId) async {
    final db = await dbProvider.database;
    var response = await db.query('sell', where: 'id = ?', whereArgs: [sellId]);
    return response;
  }

  // Fetch sales by TransactionId
  Future<List> getSellByTransactionId(transactionId) async {
    final db = await dbProvider.database;
    var response = await db
        .query('sell', where: 'transaction_id = ?', whereArgs: [transactionId]);
    return response;
  }

  // Fetch not synced sales
  Future<List> getNotSyncedSells() async {
    final db = await dbProvider.database;
    var response = await db.query('sell', where: 'is_synced = 0');
    return response;
  }

  // Update sale
  Future<int> updateSells(sellId, value) async {
    final db = await dbProvider.database;
    var response =
    await db.update('sell', value, where: 'id = ?', whereArgs: [sellId]);
    return response;
  }

  // Delete all lines where is_completed = 0
  Future<int> deleteInComplete() async {
    final db = await dbProvider.database;
    var response = await db
        .delete('sell_lines', where: 'is_completed = ?', whereArgs: [0]);
    return response;
  }

  Future<String> countSellLines({isCompleted, sellId}) async {
    String where;

    if (sellId != null) {
      where = 'sell_id = $sellId';
    } else {
      where = 'is_completed = 0';
    }

    final db = await dbProvider.database;
    var response = await db
        .rawQuery('SELECT COUNT(*) AS counts FROM sell_lines WHERE $where');
    return response[0]['counts'].toString();
  }

  // Delete a sell and corresponding sellLines from database
  deleteSell(int sellId) async {
    final db = await dbProvider.database;
    await db.delete('sell', where: 'id = ?', whereArgs: [sellId]);
    await db.delete('sell_lines', where: 'sell_id = ?', whereArgs: [sellId]);
    await db.delete('sell_payments', where: 'sell_id = ?', whereArgs: [sellId]);
  }

  // ================== Sell Return Methods ==================

  // Store sell return in the database
  Future<int> storeSellReturn(Map<String, dynamic> sellReturn) async {
    final db = await dbProvider.database;

    // Log the sell return data being inserted
    print('Inserting Sell Return: $sellReturn');

    var response = await db.insert('sell_return', sellReturn);

    // Log the response (inserted row ID)
    print('Sell Return Inserted with ID: $response');

    return response;
  }

  Future<int> updateOrInsertSellReturn(Map<String, dynamic> sellReturn) async {
    final db = await dbProvider.database;
    // Check if the sell return already exists in the database
    List<Map<String, dynamic>> existingReturns = await db.query(
        'sell_returns',
        where: 'id = ?',
        whereArgs: [sellReturn['id']]
    );

    if (existingReturns.isNotEmpty) {
      // Update existing record
      return await db.update(
          'sell_returns',
          sellReturn,
          where: 'id = ?',
          whereArgs: [sellReturn['id']]
      );
    } else {
      // Insert new record
      return await db.insert(
          'sell_returns',
          sellReturn,
          conflictAlgorithm: ConflictAlgorithm.replace
      );
    }
  }

  Future<int> deleteSellReturn(int id) async {
    final db = await dbProvider.database;
    return await db.delete(
        'sell_returns',
        where: 'id = ?',
        whereArgs: [id]
    );
  }

  // Fetch sell returns from the database
  Future<List<Map<String, dynamic>>> getSellReturns() async {
    final db = await dbProvider.database;
    var result = await db.query('sell_return');
    print('Sell Returns from DB: $result'); // Log the result
    return result;
  }

  // Fetch sell return by ID
  Future<List<Map<String, dynamic>>> getSellReturnById(int sellReturnId) async {
    final db = await dbProvider.database;
    return await db.query('sell_return', where: 'id = ?', whereArgs: [sellReturnId]);
  }


  // Fetch sell returns that are not synced
  Future<List<Map<String, dynamic>>> getNotSyncedSellReturns() async {
    final db = await dbProvider.database;
    return await db.query('sell_return', where: 'is_synced = 0');
  }
}