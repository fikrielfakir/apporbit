import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/sellDatabase.dart';
import '../models/system.dart';
import 'api.dart';

class SellApi extends Api {
  // Existing methods...

  /// Fetches a list of sell returns from the API.
  /// Optionally, you can filter by `sell_id`.
  Future<List<Map<String, dynamic>>> fetchSellReturns({String? sellId}) async {
    final url = Uri.parse('$baseUrl$apiUrl/list-sell-return');

    // Add sell_id as a query parameter if provided
    if (sellId != null) {
      url.replace(queryParameters: {'sell_id': sellId});
    }

    final token = await System().getToken();
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    try {
      final response = await http.get(url, headers: headers);

      // Log the response
      print('Fetch Sell Returns Response: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['data']);
      } else {
        throw Exception('Failed to fetch sell returns: ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to connect to the server: $e');
    }
  }

  // Existing methods...

  Future<dynamic> createSellReturn({
    required String token,
    required int transactionId,
    required String transactionDate,
    required String invoiceNo,
    required double discountAmount,
    required String discountType,
    required List<Map> products,
  }) async {
    final url = this.baseUrl + this.apiUrl + "/sell-return";
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    final body = {
      'transaction_id': transactionId,
      'transaction_date': transactionDate,
      'invoice_no': invoiceNo,
      'discount_amount': discountAmount,
      'discount_type': discountType,
      'products': products,
    };

    // Log the request data
    print('Sell Return Request Data: $body');

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(body),
      );

      // Log the response
      print('Sell Return Response: ${response.body}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to create sell return: ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to connect to the server: $e');
    }
  }

  Future<void> syncReturn(int sellId, List<Map<String, dynamic>> returnedProducts) async {
    var token = await System().getToken(); // Récupération du token
    final response = await http.post(
      Uri.parse('$baseUrl$apiUrl/sell-return'), // Using correct URL structure
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'sell_id': sellId,
        'returned_products': returnedProducts,
      }),
    );

    if (response.statusCode == 200) {
      // Mise à jour de l'état de synchronisation dans la base de données
      await SellDatabase().updateSellReturnSyncStatus(sellId);
    } else {
      throw Exception('Failed to sync return');
    }
  }

  // New method to sync all pending sell returns
  Future<void> syncSellReturns() async {
    try {
      // Get all unsynchronized sell returns from the database
      var unsyncedReturns = await SellDatabase().getUnsyncedSellReturns();

      if (unsyncedReturns.isEmpty) {
        print('No unsynced sell returns found');
        return;
      }

      print('Found ${unsyncedReturns.length} unsynced sell returns');

      for (var sellReturn in unsyncedReturns) {
        try {
          var token = await System().getToken();

          // Parse the products JSON string back to a list
          List<Map<String, dynamic>> products = List<Map<String, dynamic>>.from(
              jsonDecode(sellReturn['products'])
          );

          final url = '$baseUrl$apiUrl/sell-return';
          final headers = {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          };

          final body = {
            'transaction_id': sellReturn['transaction_id'],
            'transaction_date': sellReturn['transaction_date'],
            'invoice_no': sellReturn['invoice_no'],
            'discount_amount': sellReturn['discount_amount'],
            'discount_type': sellReturn['discount_type'],
            'products': products,
          };

          print('Syncing sell return ID: ${sellReturn['id']}');
          print('Request body: $body');

          final response = await http.post(
            Uri.parse(url),
            headers: headers,
            body: jsonEncode(body),
          );

          print('Sync response: ${response.body}');

          if (response.statusCode == 200) {
            // Update the sync status in the database
            await SellDatabase().updateSellReturnSyncStatus(sellReturn['transaction_id']);
            print('Successfully synced return ID: ${sellReturn['id']}');
          } else {
            print('Failed to sync return ID: ${sellReturn['id']}, status: ${response.statusCode}');
            throw Exception('Failed to sync return: ${response.body}');
          }
        } catch (e) {
          print('Error syncing return ID: ${sellReturn['id']}: $e');
          // Continue with next return even if one fails
        }
      }
    } catch (e) {
      print('Error in syncSellReturns: $e');
      throw Exception('Failed to sync sell returns: $e');
    }
  }

  //create a sell in api
  Future<Map<String, dynamic>> create(data) async {
    String url = this.baseUrl + this.apiUrl + "/sell";
    var token = await System().getToken();
    var response = await http.post(Uri.parse(url),
        headers: this.getHeader('$token'), body: data);
    var info = jsonDecode(response.body);
    var result;

    if (info[0]['payment_lines'] != null) {
      result = {
        'transaction_id': info[0]['id'],
        'payment_lines': info[0]['payment_lines'],
        'invoice_url': info[0]['invoice_url']
      };
    } else if (info[0]['is_quotation'] != null) {
      result = {
        'transaction_id': info[0]['id'],
        'invoice_url': info[0]['invoice_url']
      };
    } else {
      result = null;
    }
    return result;
  }

  //update a sell in api
  Future<Map<String, dynamic>> update(transactionId, data) async {
    String url = this.baseUrl + this.apiUrl + "/sell/$transactionId";
    var token = await System().getToken();
    var response = await http.put(Uri.parse(url),
        headers: this.getHeader('$token'), body: data);
    var sellResponse = jsonDecode(response.body);
    return {
      'payment_lines': sellResponse['payment_lines'],
      'invoice_url': sellResponse['invoice_url']
    };
  }

  //delete sell
  delete(transactionId) async {
    String url = this.baseUrl + this.apiUrl + "/sell/$transactionId";
    var token = await System().getToken();
    var response =
    await http.delete(Uri.parse(url), headers: this.getHeader('$token'));
    if (response.statusCode == 200) {
      var sellResponse = jsonDecode(response.body);
      return sellResponse;
    } else {
      return null;
    }
  }

  //get specified sell
  getSpecifiedSells(List transactionIds) async {
    String ids = transactionIds.join(",");
    String url = this.baseUrl + this.apiUrl + "/sell/$ids";
    var token = await System().getToken();
    var response = [];
    await http
        .get(Uri.parse(url), headers: this.getHeader('$token'))
        .then((value) {
      if (value.body.contains('data')) {
        response = jsonDecode(value.body)['data'];
        var responseTransactionIds = [];
        response.forEach((element) {
          responseTransactionIds.add(element['id']);
        });
        transactionIds.forEach((id) async {
          if (!responseTransactionIds.contains(id)) {
            await SellDatabase().getSellByTransactionId(id).then((value) {
              SellDatabase().deleteSell(value[0]['id']);
            });
          }
        });
      }
    });
    return response;
  }
}