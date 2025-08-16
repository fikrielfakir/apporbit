import 'dart:convert';

import '../apis/sell.dart';
import '../models/paymentDatabase.dart';
import '../models/sellDatabase.dart';
import '../models/system.dart';

class Sell {
  //sync sell with improved stock tracking
  Future<bool> createApiSell({sellId, bool? syncAll}) async {
    List sales;
    (syncAll != null)
        ? sales = await SellDatabase().getNotSyncedSells()
        : sales = await SellDatabase().getSellBySellId(sellId);

    for (var element in sales) {
      try {
        List products = await SellDatabase().getSellLines(element['id']);

        //model map for creating new sell with proper return amount handling
        List<Map<String, dynamic>> sale = [
          {
            'location_id': element['location_id'],
            'contact_id': element['contact_id'],
            'transaction_date': element['transaction_date'],
            'invoice_no': element['invoice_no'],
            'status': element['status'],
            'sub_status': (element['is_quotation'].toString() == '1') ? 'quotation' : null,
            'tax_rate_id': (element['tax_rate_id'] == 0) ? null : element['tax_rate_id'],
            'discount_amount': element['discount_amount'] ?? 0.0,
            'discount_type': element['discount_type'] ?? 'fixed',
            'change_return': element['change_return'] ?? 0.0,
            'return_amount': element['return_amount'] ?? 0.0,
            'products': products,
            'sale_note': element['sale_note'],
            'staff_note': element['staff_note'],
            'shipping_charges': element['shipping_charges'] ?? 0.0,
            'shipping_details': element['shipping_details'],
            'is_quotation': element['is_quotation'] ?? 0,
            'payments': await PaymentDatabase().get(element['id']),
            'latitude': element['latitude'],
            'longitude': element['longitude'],
          }
        ];

        //fetch paymentLine where is_return = 1
        List paymentDetail = await PaymentDatabase().getPaymentLineByReturnValue(element['id'], 1);
        var returnId = (paymentDetail.isNotEmpty) ? paymentDetail[0]['payment_id'] : null;

        //model map for updating an existing sell with proper stock validation
        Map<String, dynamic> editedSale = {
          'contact_id': element['contact_id'],
          'transaction_date': element['transaction_date'],
          'status': element['status'],
          'tax_rate_id': (element['tax_rate_id'] == 0) ? null : element['tax_rate_id'],
          'discount_amount': element['discount_amount'] ?? 0.0,
          'discount_type': element['discount_type'] ?? 'fixed',
          'sale_note': element['sale_note'],
          'staff_note': element['staff_note'],
          'shipping_charges': element['shipping_charges'] ?? 0.0,
          'shipping_details': element['shipping_details'],
          'is_quotation': element['is_quotation'] ?? 0,
          'change_return': element['change_return'] ?? 0.0,
          'return_amount': element['return_amount'] ?? 0.0,
          'change_return_id': returnId,
          'products': products,
          'payments': await PaymentDatabase().getPaymentLineByReturnValue(element['id'], 0),
          'latitude': element['latitude'],
          'longitude': element['longitude'],
        };

        if (element['is_synced'] == 0) {
          if (element['transaction_id'] != null) {
            // Update existing transaction
            var sell = jsonEncode(editedSale);
            Map<String, dynamic> updatedResult = await SellApi().update(element['transaction_id'], sell);
            var result = updatedResult['payment_lines'];

            if (result != null) {
              await SellDatabase().updateSells(element['id'], {
                'is_synced': 1,
                'invoice_url': updatedResult['invoice_url']
              });

              //delete existing payment lines and refresh from server
              await PaymentDatabase().delete(element['id']);
              for (var paymentLine in result) {
                await PaymentDatabase().store({
                  'sell_id': element['id'],
                  'method': paymentLine['method'],
                  'amount': paymentLine['amount'],
                  'note': paymentLine['note'],
                  'payment_id': paymentLine['id'],
                  'is_return': paymentLine['is_return'],
                  'account_id': paymentLine['account_id']
                });
              }
            }
          } else {
            // Create new transaction
            var sell = jsonEncode({'sells': sale});
            var result = await SellApi().create(sell);

            if (result != null) {
              await SellDatabase().updateSells(element['id'], {
                'is_synced': 1,
                'transaction_id': result['transaction_id'],
                'invoice_url': result['invoice_url']
              });

              if (result['payment_lines'] != null) {
                await PaymentDatabase().delete(element['id']);
                for (var paymentLine in result['payment_lines']) {
                  await PaymentDatabase().store({
                    'sell_id': element['id'],
                    'method': paymentLine['method'],
                    'amount': paymentLine['amount'],
                    'note': paymentLine['note'],
                    'payment_id': paymentLine['id'],
                    'is_return': paymentLine['is_return'],
                    'account_id': paymentLine['account_id']
                  });
                }
              }
            }
          }
        }
      } catch (e) {
        print('Error syncing sell ${element['id']}: $e');
        continue; // Continue with next sale if one fails
      }
    }
    return true;
  }

  //create payment with validation
  makePayment(List payments, int sellId) {
    for (var element in payments) {
      Map<String, dynamic> payment = {
        'sell_id': sellId,
        'method': element['method'],
        'amount': double.tryParse(element['amount'].toString()) ?? 0.0,
        'note': element['note'] ?? '',
        'account_id': element['account_id']
      };
      PaymentDatabase().store(payment);
    }
  }

  //create sell with proper validation and stock tracking
  Future<Map<String, dynamic>> createSell({
    String? invoiceNo,
    String? transactionDate,
    int? contactId,
    int? locId,
    int? taxId,
    String? discountType,
    double? discountAmount,
    double? invoiceAmount,
    double? changeReturn,
    double? returnAmount,
    double? pending,
    String? saleNote,
    String? staffNote,
    double? shippingCharges,
    String? shippingDetails,
    String? saleStatus,
    int? isQuotation,
    int? sellId,
    double? latiTude,
    double? longiTude
  }) async {
    Map<String, dynamic> sale;

    // Validate required fields
    if (locId == null || contactId == null) {
      throw Exception('Location ID and Contact ID are required');
    }

    if (sellId == null) {
      sale = {
        'transaction_date': transactionDate ?? DateTime.now().toIso8601String(),
        'invoice_no': invoiceNo,
        'contact_id': contactId,
        'location_id': locId,
        'status': saleStatus ?? 'final',
        'tax_rate_id': taxId,
        'discount_amount': discountAmount ?? 0.0,
        'discount_type': discountType ?? 'fixed',
        'invoice_amount': invoiceAmount ?? 0.0,
        'change_return': changeReturn ?? 0.0,
        'return_amount': returnAmount ?? 0.0,
        'sale_note': saleNote,
        'staff_note': staffNote,
        'shipping_charges': shippingCharges ?? 0.0,
        'shipping_details': shippingDetails,
        'pending_amount': pending ?? 0.0,
        'is_quotation': isQuotation ?? 0,
        'is_synced': 0,
        'latitude': latiTude,
        'longitude': longiTude,
      };
    } else {
      sale = {
        'contact_id': contactId,
        'transaction_date': transactionDate ?? DateTime.now().toIso8601String(),
        'location_id': locId,
        'status': saleStatus ?? 'final',
        'tax_rate_id': taxId,
        'discount_amount': discountAmount ?? 0.0,
        'discount_type': discountType ?? 'fixed',
        'invoice_amount': invoiceAmount ?? 0.0,
        'change_return': changeReturn ?? 0.0,
        'return_amount': returnAmount ?? 0.0,
        'sale_note': saleNote,
        'staff_note': staffNote,
        'shipping_charges': shippingCharges ?? 0.0,
        'shipping_details': shippingDetails,
        'pending_amount': pending ?? 0.0,
        'is_quotation': isQuotation ?? 0,
        'is_synced': 0,
        'latitude': latiTude,
        'longitude': longiTude,
      };
    }

    return sale;
  }

  //get unit_price with tax calculation
  getUnitPrice(unitPrice, taxId) async {
    double price = 0.00;
    await System().get('tax').then((value) {
      for (var element in value) {
        if (element['id'] == taxId) {
          price = (unitPrice * 100) / (double.parse(element['amount'].toString()) + 100);
        }
      }
    });
    return price;
  }

  //add to cart with proper stock validation
  Future<bool> addToCart(product, sellId) async {
    try {
      //calculate unit price after considering tax
      double price = (product['tax_rate_id'] != 0 && product['tax_rate_id'] != null)
          ? await getUnitPrice(
          double.parse(product['unit_price'].toString()),
          product['tax_rate_id'])
          : double.parse(product['unit_price'].toString());

      var sellLine = {
        'sell_id': sellId,
        'product_id': product['product_id'],
        'variation_id': product['variation_id'],
        'quantity': 1,
        'unit_price': price,
        'tax_rate_id': (product['tax_rate_id'] == 0) ? null : product['tax_rate_id'],
        'discount_amount': 0.00,
        'discount_type': 'fixed',
        'note': '',
        'is_completed': 0
      };

      // Check if item already exists in cart
      List checkSellLine = await SellDatabase().checkSellLine(
          sellLine['variation_id'],
          sellId: sellId);

      if (checkSellLine.length == 0) {
        // First check if the product has stock tracking enabled
        if (product['enable_stock'] != null && product['enable_stock'] != 0) {
          // Check stock availability before adding
          if (product['stock_available'] != null && product['stock_available'] > 0) {
            await SellDatabase().store(sellLine);
            return true;
          } else {
            throw Exception('Insufficient stock available');
          }
        } else {
          // No stock tracking, add to cart directly
          await SellDatabase().store(sellLine);
          return true;
        }
      } else {
        // Item already in cart
        return false;
      }
    } catch (e) {
      print('Error adding to cart: $e');
      rethrow;
    }
  }

  //Reset cart
  resetCart() async {
    await SellDatabase().deleteInComplete();
  }

  //get cart item count
  Future<String> cartItemCount({isCompleted, sellId}) async {
    return await SellDatabase().countSellLines(isCompleted: isCompleted, sellId: sellId);
  }

  //create sell map for refresh
  Map<String, dynamic> createSellMap(Map sell, double change, double pending) {
    Map<String, dynamic> sale = {
      'transaction_date': sell['transaction_date'],
      'invoice_no': sell['invoice_no'],
      'contact_id': sell['contact_id'],
      'location_id': sell['location_id'],
      'status': sell['status'],
      'tax_rate_id': (sell['tax_id'] != 0) ? sell['tax_id'] : null,
      'discount_amount': sell['discount_amount'] ?? 0.0,
      'discount_type': sell['discount_type'] ?? 'fixed',
      'invoice_amount': double.tryParse(sell['final_total'].toString()) ?? 0.0,
      'change_return': change,
      'return_amount': sell['return_amount'] ?? 0.0,
      'sale_note': sell['additional_notes'],
      'staff_note': sell['staff_note'],
      'shipping_charges': double.tryParse(sell['shipping_charges'].toString()) ?? 0.0,
      'shipping_details': sell['shipping_details'],
      'pending_amount': pending,
      'is_synced': 1,
      'latitude': sell['latitude'],
      'longitude': sell['longitude'],
    };
    return sale;
  }


}