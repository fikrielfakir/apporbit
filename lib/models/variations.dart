import 'dart:convert';

import 'package:pos_final/api_end_points.dart';
import 'package:sqflite/sqflite.dart';

import '../apis/api.dart';
import '../apis/variations.dart';
import '../models/system.dart';
import 'database.dart';

class Variations {
  late DbProvider dbProvider;

  Variations() {
    dbProvider = new DbProvider();
  }

  //save variations and variations_locations
  store() async {
    String? link = ApiEndPoints.baseUrl + Api().apiUrl + "/variation?per_page=3000&not_for_selling=0";
    do {
      Map response = await VariationsApi().get("$link");
      List products = await response['products'];
      final db = await dbProvider.database;
      Batch batch = db.batch();
      List processedProductIds = [];

      //save variations
      products.forEach((variation) {
        Map<String, dynamic> tempProduct = {};
        tempProduct['product_id'] = variation['product_id'];
        tempProduct['variation_id'] = variation['variation_id'];
        tempProduct['product_name'] = variation['product_name'];
        tempProduct['product_variation_name'] =
        variation['product_variation_name'];
        tempProduct['variation_name'] = variation['variation_name'];
        tempProduct['display_name'] = variation['product_name'] +
            " " +
            variation['product_variation_name'] +
            " " +
            variation['variation_name'];
        tempProduct['sku'] = variation['sku'];
        tempProduct['sub_sku'] = variation['sub_sku'];
        tempProduct['type'] = variation['type'];
        tempProduct['enable_stock'] = variation['enable_stock'];
        tempProduct['brand_id'] = variation['brand_id'];
        tempProduct['unit_id'] = variation['unit_id'];
        tempProduct['category_id'] = variation['category_id'];
        tempProduct['sub_category_id'] = variation['sub_category_id'];
        tempProduct['tax_id'] = variation['tax_id'];
        tempProduct['default_sell_price'] = variation['default_sell_price'];
        tempProduct['sell_price_inc_tax'] = variation['sell_price_inc_tax'];
        tempProduct['product_image_url'] = variation['product_image_url'];
        tempProduct['product_description'] = variation['product_description'];
        List<Map<String, dynamic>> groupId = [];
        if (variation['selling_price_group'].length > 0) {
          variation['selling_price_group'].forEach((group) {
            groupId.add({
              'key': group['price_group_id'],
              'value': group['price_inc_tax']
            });
          });
          tempProduct['selling_price_group'] = jsonEncode(groupId);
        }
        //save product available in different locations
        variation['product_locations'].forEach((value) {
          if (!processedProductIds.contains(variation['product_id'])) {
            var tempProductLocation = {
              'product_id': variation['product_id'],
              'location_id': value['id']
            };
            batch.insert('product_locations', tempProductLocation);
          }
        });
        processedProductIds.add(variation['product_id']);

        if (variation['variation_location_details'].length > 0) {
          //save variation details
          variation['variation_location_details'].forEach((variationDetail) {
            Map<String, dynamic> tempProductDetail = {};
            tempProductDetail['product_id'] = variationDetail['product_id'];
            tempProductDetail['variation_id'] = variationDetail['variation_id'];
            tempProductDetail['location_id'] = variationDetail['location_id'];
            tempProductDetail['qty_available'] =
                double.parse(variationDetail['qty_available']);
            batch.insert('variations_location_details', tempProductDetail);
          });
        }
        batch.insert('variations', tempProduct);
      });
      link = response['nextLink'];
      await batch.commit(noResult: true);
    } while (link != null);
  }

  //get all variations from cache with stock calculation
  getProductsFromCache({
    int? brandId,
    int? categoryId,
    int? subCategoryId,
    bool? inStock,
    int? locationId,
    String? searchTerm,
    int? offset,
    int? byAlphabets,
    int? byPrice,
  }) async {
    final db = await DbProvider.db.database;

    String whereClause = '1=1';
    List<dynamic> whereArgs = [];

    // Add location filter
    if (locationId != null && locationId != 0) {
      whereClause += ' AND V.product_id IN (SELECT product_id FROM product_locations WHERE location_id = ?)';
      whereArgs.add(locationId);
    }

    if (searchTerm != null && searchTerm.isNotEmpty) {
      whereClause += ' AND (V.display_name LIKE ? OR V.sub_sku LIKE ?)';
      whereArgs.addAll(['%$searchTerm%', '%$searchTerm%']);
    }

    if (brandId != null && brandId != 0) {
      whereClause += ' AND V.brand_id = ?';
      whereArgs.add(brandId);
    }

    if (categoryId != null && categoryId != 0) {
      whereClause += ' AND V.category_id = ?';
      whereArgs.add(categoryId);
    }

    if (subCategoryId != null && subCategoryId != 0) {
      whereClause += ' AND V.sub_category_id = ?';
      whereArgs.add(subCategoryId);
    }

    String orderBy = '';
    if (byAlphabets != null) {
      orderBy = 'V.display_name ${byAlphabets == 0 ? 'ASC' : 'DESC'}';
    } else if (byPrice != null) {
      orderBy = 'V.default_sell_price ${byPrice == 0 ? 'ASC' : 'DESC'}';
    } else {
      orderBy = 'V.variation_id';
    }

    int limit = 10; // Match the limit used in the main get method
    int offsetValue = offset != null ? (offset - 1) * limit : 0;

    // Get product last sync datetime for stock calculation
    String productLastSync = await System().getProductLastSync() ?? '';

    String query = '''
      SELECT DISTINCT V.*,
      CASE 
        WHEN (VLD.qty_available IS NULL AND V.enable_stock = 0) THEN 9999 
        WHEN (VLD.qty_available IS NULL AND V.enable_stock = 1) THEN 0 
        ELSE COALESCE(VLD.qty_available, 0) - COALESCE(
          (SELECT SUM(SL.quantity) FROM sell_lines AS SL JOIN sell AS S ON SL.sell_id = S.id
           WHERE (SL.is_completed = 0 OR S.transaction_date > ?) 
           AND S.location_id = ? 
           AND SL.variation_id = V.variation_id 
           AND S.is_quotation = 0), 0)
      END as "stock_available"
      FROM variations as V
      LEFT JOIN variations_location_details as VLD 
        ON V.variation_id = VLD.variation_id AND VLD.location_id = ?
      WHERE $whereClause
    ''';

    if (inStock == true) {
      query += ' AND stock_available > 0';
    }

    query += ' ORDER BY $orderBy LIMIT $limit OFFSET $offsetValue';

    List<dynamic> queryArgs = [productLastSync, locationId, locationId, ...whereArgs];

    try {
      List<Map<String, dynamic>> result = await db.rawQuery(query, queryArgs);
      return result;
    } catch (e) {
      print('Error in getProductsFromCache: $e');
      // Fallback to simple query without stock calculation
      List<Map<String, dynamic>> result = await db.query(
        'variations',
        where: whereClause.replaceAll('V.', ''),
        whereArgs: whereArgs.skip(3).toList(), // Skip the first 3 args that were for stock calculation
        orderBy: orderBy.replaceAll('V.', ''),
        limit: limit,
        offset: offsetValue,
      );

      // Add basic stock info
      for (var product in result) {
        product['stock_available'] = product['enable_stock'] == 0 ? 9999 : 0;
      }

      return result;
    }
  }

  get(
      {brandId,
        categoryId,
        subCategoryId,
        searchTerm,
        locationId,
        inStock,
        barcode,
        offset,
        byAlphabets,
        byPrice}) async {
    final db = await dbProvider.database;
    inStock = (inStock == null) ? false : inStock;

    var where = 'WHERE 1=1';
    var order = '';

    if (byAlphabets == 0) {
      order += 'product_name,';
    } else if (byAlphabets == 1) {
      order += 'product_name DESC,';
    }

    if (byPrice == 0) {
      order += 'sell_price_inc_tax,';
    } else if (byPrice == 1) {
      order += 'sell_price_inc_tax DESC,';
    }

    if (brandId != 0 && brandId != null) {
      where += ' AND V.brand_id = $brandId';
    }

    if (categoryId != 0 && categoryId != null) {
      where += ' AND V.category_id = $categoryId';
    }

    if (subCategoryId != 0 && subCategoryId != null) {
      where += ' AND V.sub_category_id = $subCategoryId';
    }

    if (searchTerm.length > 0) {
      where +=
      ' AND (V.display_name LIKE "%$searchTerm%" OR V.sub_sku LIKE "%$searchTerm%")';
    }

    if (inStock) {
      where += ' AND stock_available > 0';
    }

    if (barcode != null) {
      where += ' AND V.sub_sku LIKE "$barcode"';
    }

    //get product last sync datetime
    String productLastSync = await System().getProductLastSync();
    var result = db.rawQuery('SELECT DISTINCT V.* ,'
        'CASE WHEN (qty_available IS NULL AND enable_stock = 0) THEN 9999 '
        'WHEN (qty_available IS NULL AND enable_stock = 1) THEN 0 '
        'ELSE (qty_available - COALESCE('
        ' (SELECT SUM(SL.quantity) FROM sell_lines AS SL JOIN sell AS S on SL.sell_id = S.id'
        ' WHERE (SL.is_completed = 0 OR S.transaction_date > "$productLastSync") AND'
        ' S.location_id = $locationId AND SL.variation_id=V.variation_id AND S.is_quotation = 0), 0))'
        'END as "stock_available" '
        'FROM "variations" as V '
        'JOIN "product_locations" as PL '
        'on (V.product_id = PL.product_id AND PL.location_id = $locationId )'
        ' LEFT JOIN "variations_location_details" as VLD '
        'ON V.variation_id = VLD.variation_id AND VLD.location_id = $locationId '
        '$where ORDER BY ${order}id LIMIT 10 OFFSET ($offset-1)*10');
    return result;
  }

  //total no. of rows in variations table
  checkProductTable({var locationId}) async {
    final db = await dbProvider.database;
    var res = (locationId != null)
        ? await db.rawQuery('SELECT count(*)'
        'FROM "variations" as V '
        'JOIN "product_locations" as PL '
        'on (V.product_id = PL.product_id AND PL.location_id = $locationId )'
        ' LEFT JOIN "variations_location_details" as VLD '
        'ON V.variation_id = VLD.variation_id AND VLD.location_id = $locationId ')
        : await db.rawQuery("SELECT count(*) FROM variations", null);
    return res[0]['count(*)'];
  }

//  refresh variations and variations_locations
  refresh() async {
    var count = await checkProductTable();
    if (count > 0) {
      deleteVariationDetails().then((value) async {
        await store();
      });
    } else {
      await store();
    }
  }

  //empty variations
  deleteVariationDetails() async {
    final db = await dbProvider.database;
    await db.rawQuery("DELETE FROM variations");
    await db.rawQuery("DELETE FROM variations_location_details");
    await db.rawQuery("DELETE FROM product_locations");
  }
}