import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import '../helpers/otherHelpers.dart';
import '../locale/MyLocalizations.dart';
import '../models/paymentDatabase.dart';
import '../models/qr.dart';
import '../models/sellDatabase.dart';
import '../models/system.dart';
import '../models/contact_model.dart';


class InvoiceFormatter {
  Future<String> generateReturnInvoice({
    required int originalSellId,
    required int taxId,
    required BuildContext context,
    required List<Map<String, dynamic>> returnedProducts,
  }) async {
    // Fetch original sell data
    List sells = await SellDatabase().getSellBySellId(originalSellId);
    var customer = await Contact().getCustomerDetailById(sells[0]['contact_id']);
    var businessDetails = await Helper().getFormattedBusinessDetails();

    // Fetch location details
    var location = await System().get('location');

    // Generate product details HTML
    String productsHtml = await _generateProductDetailsHtml(
      products: returnedProducts,
      context: context,
    );

    // Calculate totals
    double subTotal = 0.0;
    for (var product in returnedProducts) {
      subTotal += product['quantity'] * product['unit_price'];
    }

    // Generate invoice HTML
    String invoice = '''
    <section class="invoice print_section" id="receipt_section">
      <div class="ticket">
        <p class="centered headings">${businessDetails['name']}</p>
        <p class="centered">${businessDetails['taxLabel']} ${businessDetails['taxNumber']}</p>
        <div class="textbox-info">
          <p><strong>${AppLocalizations.of(context).translate('return_invoice')}</strong></p>
          <p>${AppLocalizations.of(context).translate('invoice_no')}: ${sells[0]['invoice_no']}</p>
          <p>${AppLocalizations.of(context).translate('date')}: ${sells[0]['transaction_date']}</p>
        </div>
        <table class="border-bottom width-100 table-f-12 mb-10">
          <tbody>$productsHtml</tbody>
        </table>
        <div class="flex-box">
          <p class="width-50 text-left"><strong>${AppLocalizations.of(context).translate('sub_total')}:</strong></p>
          <p class="width-50 text-right"><strong>${businessDetails['symbol']} ${Helper().formatCurrency(subTotal.toString())}</strong></p>
        </div>
      </div>
    </section>
  ''';

    return invoice;
  }

  Future<String> _generateProductDetailsHtml({
    required List<Map<String, dynamic>> products,
    required BuildContext context,
  }) async {
    String productHtml = '''
      <tr class="bb-lg">
        <th width="30%">${AppLocalizations.of(context).translate('products')}</th>
        <th width="20%">${AppLocalizations.of(context).translate('quantity')}</th>
        <th width="20%">${AppLocalizations.of(context).translate('unit_price')}</th>
        <th width="20%">${AppLocalizations.of(context).translate('sub_total')}</th>
      </tr>
    ''';

    for (var product in products) {
      String productName = product['name'] ?? 'منتج غير معروف';
      String productQuantity = product['quantity'].toString();
      String productPrice = product['unit_price'].toString();
      String totalProductPrice = (product['quantity'] * product['unit_price']).toString();

      productHtml += '''
        <tr class="bb-lg">
          <td width="30%"><p>$productName</p></td>
          <td width="20%"><p>${Helper().formatQuantity(productQuantity)}</p></td>
          <td width="20%"><p>${Helper().formatCurrency(productPrice)}</p></td>
          <td width="20%"><p>${Helper().formatCurrency(totalProductPrice)}</p></td>
        </tr>
      ''';
    }

    return productHtml;
  }
}