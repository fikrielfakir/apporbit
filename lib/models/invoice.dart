import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../helpers/otherHelpers.dart';
import '../locale/MyLocalizations.dart';
import '../models/paymentDatabase.dart';
import '../models/sellDatabase.dart';
import '../models/system.dart';
import 'contact_model.dart';

class InvoiceFormatter {
  final String userName; // Ajout de cette ligne
  double subTotal = 0;
  String taxName = 'taxRates';
  double inlineDiscountAmount = 0.0;
  double inlineTaxAmount = 0.0;
  double tax = 0;
  InvoiceFormatter({required this.userName});

  Future<String> generateInvoice(int sellId, int taxId, BuildContext context) async {
    if (sellId == null || taxId == null) {
      return _errorInvoiceHtml('ID de vente ou ID de taxe invalide');
    }

    try {
      // Initialisation des variables
      final businessDetails = await Helper().getFormattedBusinessDetails();
      final sells = await SellDatabase().getSellBySellId(sellId);

      if (sells.isEmpty) {
        return _errorInvoiceHtml('Aucune donnée de vente trouvée');
      }

      final sell = sells.first;
      final customer = await Contact().getCustomerDetailById(sell['contact_id']);
      final locationDetails = await _getLocationDetails(sell['location_id']);
      final paymentList = await PaymentDatabase().get(sell['id'], allColumns: true);

      // Formatage des dates et montants
      final dateTime = DateTime.parse(sell['transaction_date']);
      final date = DateFormat("dd/MM/yyyy").format(dateTime);

      // Génération du HTML de la liste des produits d'abord pour calculer le sous-total
      final productsHtml = await _generateProductListHtml(sell['id'], context);

      // Calcul des montants financiers après le chargement des produits
      final financials = await _calculateFinancials(
          sell: sell,
          paymentList: paymentList,
          taxId: taxId,
          context: context,
          symbol: businessDetails['symbol']
      );

      // Construction des sections HTML
      final htmlSections = _buildHtmlSections(
          sell: sell,
          financials: financials,
          businessDetails: businessDetails,
          customer: customer,
          locationDetails: locationDetails,
          date: date,
          context: context
      );

      // Génération du HTML complet de la facture
      return _buildInvoiceHtml(
          businessDetails: businessDetails,
          locationDetails: locationDetails,
          taxLabel: businessDetails['taxLabel'],
          taxNumber: businessDetails['taxNumber'],
          invoiceNo: sell['invoice_no'],
          date: date,
          customerName: customer['name'] ?? '',
          customerAddress: _formatCustomerAddress(customer),
          customerMobile: customer['mobile'] ?? '',
          productsHtml: productsHtml,
          shippingHtml: htmlSections['shippingHtml'] ?? '',
          discountHtml: htmlSections['discountHtml'] ?? '',
          inlineDiscountHtml: htmlSections['inlineDiscountHtml'] ?? '',
          taxHtml: htmlSections['taxHtml'] ?? '',
          inlineTaxesHtml: htmlSections['inlineTaxesHtml'] ?? '',
          returnHtml: htmlSections['returnHtml'] ?? '',
          totalAmount: financials['totalAmount'] ?? '0.00',
          sTotal: financials['sTotal'] ?? '0.00',
          totalPaidAmount: financials['totalPaidAmount'] ?? '0.00',
          dueHtml: htmlSections['dueHtml'] ?? '',
          symbol: businessDetails['symbol'],
          returnAmount: financials['returnAmount'] ?? 0.0
      );

    } catch (e) {
      print('Erreur lors de la génération de la facture: $e');
      return _errorInvoiceHtml('Erreur lors de la génération de la facture: ${e.toString()}');
    }
  }

  Future<String> _generateProductListHtml(int sellId, BuildContext context) async {
    try {
      final products = await SellDatabase().get(sellId: sellId);
      print('[DEBUG] ${products.length} produits récupérés pour la facture');

      if (products.isEmpty) {
        return '''
        <tr>
          <td colspan="4" style="text-align: center; padding: 20px; color: #666;">
            Aucun produit trouvé dans cette vente
          </td>
        </tr>
        ''';
      }

      String html = '''
      <thead>
        <tr>
          <th style="text-align: left; padding: 10px; border-bottom: 2px solid #ddd;">Article</th>
          <th style="text-align: center; padding: 10px; border-bottom: 2px solid #ddd;">Qté</th>
          <th style="text-align: right; padding: 10px;border-bottom: 2px solid #ddd;">PU</th>
          <th style="text-align: right; padding: 10px;  border-bottom: 2px solid #ddd;">Total</th>
        </tr>
      </thead>
      <tbody>
      ''';

      subTotal = 0.0;
      inlineDiscountAmount = 0.0;
      inlineTaxAmount = 0.0;

      for (var product in products) {
        try {
          String name = product['name']?.toString() ?? 'N/A';
          String sku = product['sub_sku']?.toString() ?? '';
          double qty = double.tryParse(product['quantity']?.toString() ?? '0') ?? 0;
          double price = double.tryParse(product['unit_price']?.toString() ?? '0') ?? 0;
          int taxId = int.tryParse(product['tax_rate_id']?.toString() ?? '0') ?? 0;
          double discountAmount = double.tryParse(product['discount_amount']?.toString() ?? '0') ?? 0;
          String discountType = product['discount_type']?.toString() ?? 'fixed';

          // Calcul des totaux par ligne
          Map<String, dynamic> amounts = await Helper().calculateTaxAndDiscount(
            discountAmount: discountAmount,
            discountType: discountType,
            unitPrice: price,
            taxId: taxId,
          );

          inlineDiscountAmount += amounts['discountAmount'] ?? 0;
          inlineTaxAmount += amounts['taxAmount'] ?? 0;

          String finalPrice = await Helper().calculateTotal(
            taxId: taxId,
            discountAmount: amounts['discountAmount'],
            discountType: discountType,
            unitPrice: price,
          );

          double lineTotal = qty * double.parse(finalPrice);
          subTotal += lineTotal;

          html += '''
          <tr>
            <td style="padding: 10px; border-bottom: 1px solid #eee; vertical-align: top;">
              <div style="font-weight: 500;">$name</div>
             
            </td>
            <td style="text-align: center; padding: 10px; border-bottom: 1px solid #eee; vertical-align: top;">
              ${qty.toStringAsFixed(2).replaceAll('.00', '')}
            </td>
            <td style="text-align: right; padding: 10px; border-bottom: 1px solid #eee; vertical-align: top;">
              ${Helper().formatCurrency(price)}
              ${discountAmount > 0 ? '<div style="font-size: 0.85em; color: #e67e22;">-${Helper().formatCurrency(discountAmount)} ${discountType == 'percentage' ? '%' : ''}</div>' : ''}
            </td>
            <td style="text-align: right; padding: 10px; border-bottom: 1px solid #eee; vertical-align: top;">
              ${Helper().formatCurrency(lineTotal)}
            </td>
          </tr>
          ''';
        } catch (e) {
          print('[ERREUR] Traitement du produit: $e');
          html += '''
          <tr>
            <td colspan="4" style="color: red; padding: 10px; border-bottom: 1px solid #eee;">
              Erreur d'affichage du produit: ${e.toString()}
            </td>
          </tr>
          ''';
        }
      }

      html += '</tbody>';
      return html;
    } catch (e) {
      print('[ERREUR] Génération de la liste des produits: $e');
      return '''
      <tr>
        <td colspan="4" style="color: red; text-align: center; padding: 20px;">
          Erreur de chargement des produits: ${e.toString()}
        </td>
      </tr>
      ''';
    }
  }

  Future<String> _getLocationDetails(int locationId) async {
    try {
      final locations = await System().get('location');
      final location = locations.firstWhere(
            (element) => element['id'] == locationId,
        orElse: () => {},
      );

      if (location.isEmpty) return '';

      return [
        if (location['landmark'] != null) '${location['landmark']},',
        if (location['city'] != null) '${location['city']},',
        if (location['state'] != null) '${location['state']},',
        if (location['country'] != null) location['country'],
      ].join(' ');
    } catch (e) {
      print('[ERREUR] Obtention des détails du lieu: $e');
      return '';
    }
  }

  String _formatCustomerAddress(Map customer) {
    try {
      return [
        if (customer['address_line_1'] != null) customer['address_line_1'],
        if (customer['address_line_2'] != null) customer['address_line_2'],
        if (customer['city'] != null) customer['city'],
        if (customer['state'] != null) customer['state'],
        if (customer['country'] != null) customer['country'],
      ].where((part) => part != null && part.isNotEmpty).join(', ');
    } catch (e) {
      print('[ERREUR] Formatage de l\'adresse du client: $e');
      return '';
    }
  }

  Future<Map<String, dynamic>> _calculateFinancials({
    required Map sell,
    required List paymentList,
    required int taxId,
    required BuildContext context,
    required String symbol
  }) async {
    try {
      setTax(taxId);

      // Calcul des totaux de paiement
      final totalPaidAmount = paymentList.fold(0.0, (sum, element) {
        return element['is_return'] == 0 ? sum + element['amount'] : sum - element['amount'];
      });

      // Obtention du montant de retour depuis les données de vente
      final returnAmount = double.tryParse(sell['return_amount']?.toString() ?? '0') ?? 0;

      // Calcul des montants de la facture
      final amounts = getTotalAmount(
          discountType: sell['discount_type'],
          discountAmount: sell['discount_amount'],
          symbol: symbol
      );

      // Inclusion du montant de retour dans le calcul total
      final totalAmountValue = (double.tryParse(amounts['totalAmount'] ?? '0') ?? 0) +
          (double.tryParse(sell['shipping_charges']?.toString() ?? '0') ?? 0) -
          returnAmount;

      final totalAmount = Helper().formatCurrency(totalAmountValue);
      final sTotal = Helper().formatCurrency(subTotal);

      // Calcul du montant dû
      double dueAmount = 0.0;
      if (totalPaidAmount < totalAmountValue) {
        dueAmount = totalAmountValue - totalPaidAmount;
      }

      return {
        'totalAmount': totalAmount,
        'sTotal': sTotal,
        'totalPaidAmount': Helper().formatCurrency(totalPaidAmount),
        'returnAmount': returnAmount,
        'dueAmount': dueAmount,
        'taxAmount': amounts['taxAmount'],
        'discountAmount': amounts['discountAmount'],
        'discountType': amounts['discountType'],
        'inlineDiscountAmount': inlineDiscountAmount,
        'inlineTaxAmount': inlineTaxAmount,
      };
    } catch (e) {
      print('[ERREUR] Calcul des données financières: $e');
      return {
        'totalAmount': '0.00',
        'sTotal': '0.00',
        'totalPaidAmount': '0.00',
        'returnAmount': 0.0,
        'dueAmount': 0.0,
        'taxAmount': '0.00',
        'discountAmount': 0.0,
        'discountType': 'fixed',
        'inlineDiscountAmount': 0.0,
        'inlineTaxAmount': 0.0,
      };
    }
  }

  Map<String, String> _buildHtmlSections({
    required Map sell,
    required Map financials,
    required Map businessDetails,
    required Map customer,
    required String locationDetails,
    required String date,
    required BuildContext context
  }) {
    final htmlSections = <String, String>{};

    // Section montant de retour
    if (financials['returnAmount'] > 0) {
      htmlSections['returnHtml'] = '''
        <div class="totals-row">
          <span>Montant du retour:</span>
          <span>(-) ${businessDetails['symbol']} ${Helper().formatCurrency(financials['returnAmount'])}</span>
        </div>
      ''';
    }

    // Sections remise
    if (financials['discountAmount'] > 0) {
      htmlSections['discountHtml'] = '''
        <div class="totals-row">
          <span>Remise (${financials['discountType']}):</span>
          <span>(-) ${businessDetails['symbol']} ${Helper().formatCurrency(financials['discountAmount'])}</span>
        </div>
      ''';
    }

    if (financials['inlineDiscountAmount'] > 0) {
      htmlSections['inlineDiscountHtml'] = '''
  <div class="totals-row">
    <span>Remise incluse:</span>
    <span>(-) ${businessDetails['symbol']} ${Helper().formatCurrency(financials['inlineDiscountAmount'])}</span>
  </div>
''';
    }

    // Section frais de livraison
    if (sell['shipping_charges'] >= 0.01) {
      htmlSections['shippingHtml'] = '''
  <div class="totals-row">
    <span>Frais de livraison:</span>
    <span>${businessDetails['symbol']} ${Helper().formatCurrency(sell['shipping_charges'])}</span>
  </div>
''';
    }

    // Sections taxes
    if (taxName != "taxRates") {
      htmlSections['taxHtml'] = '''
  <div class="totals-row">
    <span>Taxe ($taxName):</span>
    <span>(+) ${businessDetails['symbol']} ${financials['taxAmount']}</span>
  </div>
''';
    }

    if (financials['inlineTaxAmount'] > 0) {
      htmlSections['inlineTaxesHtml'] = '''
  <div class="totals-row">
    <span>Taxe incluse:</span>
    <span>(+) ${businessDetails['symbol']} ${Helper().formatCurrency(financials['inlineTaxAmount'])}</span>
  </div>
''';
    }

    // Section montant dû
    if (financials['dueAmount'] > 0) {
      htmlSections['dueHtml'] = '''
  <div class="totals-row" style="font-weight: bold;">
    <span>Total dû:</span>
    <span>${businessDetails['symbol']} ${Helper().formatCurrency(financials['dueAmount'])}</span>
  </div>
''';
    }

    return htmlSections;
  }

  String _buildInvoiceHtml({
    required Map businessDetails,
    required String locationDetails,
    required String taxLabel,
    required String taxNumber,
    required String invoiceNo,
    required String date,
    required String customerName,
    required String customerAddress,
    required String customerMobile,
    required String productsHtml,
    required String shippingHtml,
    required String discountHtml,
    required String inlineDiscountHtml,
    required String taxHtml,
    required String inlineTaxesHtml,
    required String returnHtml,
    required String totalAmount,
    required String sTotal,
    required String totalPaidAmount,
    required String dueHtml,
    required String symbol,
    required double returnAmount,
  }) {
    return '''<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Facture $invoiceNo - ${businessDetails['name']}</title>
    <style>
        /* Styles de base avec variables améliorées */
        :root {
            --pos-width: 110mm;
            --a4-width: 210mm;
            --letter-width: 215.9mm;
            --base-font-size: 14;
            --base-padding: 5mm;
            --border-color: #e0e0e0;
            --text-color: #333;
            --accent-color: #000000;
            --light-bg: #f9f9f9;
            --highlight-color: #f5f5f5;
        }
        
        body {
            font-family: 'Arial', sans-serif;
            margin: 0;
            padding: 0;
            font-size: var(--base-font-size);
            color: var(--text-color);
            line-height: 1.4;
            background: #fff;
        }
        
        .invoice-container {
            width: 100%;
            max-width: 100%;
            margin: 0 auto;
            padding: var(--base-padding);
            background: white;
            box-sizing: border-box;
            position: relative;
            z-index: 1;
        }
        
        /* Logo de fond */
        .background-logo {
            position: absolute;
            top: 50%;
            left: 50%;
            transform: translate(-50%, -50%);
            opacity: 0.04;
            width: 80%;
            height: auto;
            z-index: -1;
            pointer-events: none;
        }
        
        /* En-tête amélioré avec meilleur espacement */
        .header {
            display: flex;
            flex-direction: column;
            align-items: center;
            margin-bottom: 0mm;
            padding-bottom: 3mm;
            border-bottom: 1px solid var(--border-color);
        }
        
        .logo-container {
            margin-bottom: 0mm;
            max-width: 60mm;
        }
        
        .logo-container img {
            max-width: 100%;
            height: auto;
        }
        
        .business-name {
            font-size: calc(var(--base-font-size) * 1.4);
            font-weight: bold;
            margin-bottom: 0mm;
            color: var(--accent-color);
        }
        
        .business-info {
            font-size: calc(var(--base-font-size) * 0.9);
            margin-bottom: 0mm;
            text-align: center;
            line-height: 1.2;
        }
        
        .invoice-title {
            font-size: calc(var(--base-font-size) * 1.8);
            font-weight: bold;
            margin: 3mm 0;
            color: var(--accent-color);
            letter-spacing: 0.5px;
        }
        
        /* Métadonnées de facture avec meilleure organisation */
        .invoice-meta {
            padding: 2mm;
            border-radius: 2mm;
            margin-bottom: 0mm;
        }
        
        .meta-row {
            display: flex;
            justify-content: space-between;
            margin-bottom: 0mm;
            flex-wrap: wrap;
        }
        
        .meta-row strong {
            color: var(--accent-color);
        }
        
        /* Section info client améliorée */
        .customer-info {
            margin-bottom: 0mm;
            padding: 3mm;
            border: 1px solid var(--border-color);
            border-radius: 2mm;
            
        }
        
        .customer-info strong {
            display: block;
            margin-bottom: 0mm;
            color: var(--accent-color);
            font-size: calc(var(--base-font-size) * 1.5);
        }
        
        /* Tableau produits amélioré */
        .product-table {
            width: 100%;
            border-collapse: collapse;
            margin-bottom: 0mm;
            font-weight: bold;
            font-size: calc(var(--base-font-size) * 1.5);
        }
        
        .product-table th {
            text-align: left;
            padding: 2mm;
            border-bottom: 2px solid var(--accent-color);
            font-weight: bold;
          
        }
        
        .product-table td {
            padding: 2mm;
            border-bottom: 1px solid var(--border-color);
        }
        
        .product-table tr:nth-child(even) {
            
        }
        
        /* Section totaux améliorée */
        .totals {
            margin-bottom: 0mm;
            border: 1px solid var(--border-color);
            border-radius: 2mm;
            padding: 2mm;
        }
        
        .totals-row {
            display: flex;
            justify-content: space-between;
            padding: 1.5mm 1mm;
        }
        
        .total-bold {
            font-weight: bold;
            font-size: calc(var(--base-font-size) * 1.8);
            border-top: 1px solid var(--accent-color);
            border-bottom: 1px solid var(--accent-color);
            margin: 3mm 0 1mm;
            padding: 2mm 1mm;
           
            color: var(--accent-color);
        }
        
        /* Code-barres et pied de page améliorés */
        .barcode-container {
            margin: 6mm 0;
            text-align: center;
            padding: 2mm;
            border-top: 1px dashed var(--border-color);
            border-bottom: 1px dashed var(--border-color);
        }
        
        .barcode {
            font-family: 'Libre Barcode 128', cursive;
            font-size: 42px;
            margin: 2mm 0;
        }
        
        .barcode-text {
            font-size: calc(var(--base-font-size) * 0.9);
            letter-spacing: 3px;
            color: var(--accent-color);
            font-weight: bold;
        }
        
        .footer {
            text-align: center;
            margin-top: 6mm;
            font-size: calc(var(--base-font-size) * 1.5);
            padding: 3mm 0;
            border-top: 1px solid var(--border-color);
            color: var(--accent-color);
        }
        
        /* Disposition des colonnes du tableau */
        .col-item {
            width: 45%;
        }
        
        .col-qty {
            width: 15%;
            text-align: center;
        }
        
        .col-price {
            width: 20%;
            text-align: right;
        }
        
        .col-total {
            width: 20%;
            text-align: right;
        }
        
        /* Classes d'aide */
        .text-right {
            text-align: right;
        }
        
        .text-center {
            text-align: center;
        }
        
        /* Styles responsives */
        @media screen and (min-width: 481px) {
            :root {
                --base-font-size: 14px;
                --base-padding: 10mm;
            }
           
            
            .invoice-container {
                max-width: var(--a4-width);
                margin: 10px auto;
                box-shadow: 0 3px 10px rgba(0,0,0,0.1);
                border-radius: 2mm;
            }
        }
        
        @media screen and (max-width: 380px) {
            :root {
                --base-padding: 3mm;
            }
            
            .col-item {
                width: 40%;
            }
            
            .product-table th, .product-table td {
                padding: 1mm;
            }
        }
        
        /* Styles pour imprimante POS */
        @media print and (max-width: 110mm) {
            :root {
                --base-font-size: 14px;
                --base-padding: 2mm;
            }
            
            body {
                width: var(--pos-width);
            }
            
            .invoice-container {
                width: 100%;
                padding: var(--base-padding);
                border: none;
                box-shadow: none;
            }
        }
        
        /* Styles pour papier A4/Lettre */
        @media print and (min-width: 111mm) {
            :root {
                --base-font-size: 14px;
                --base-padding: 10mm;
            }
            
            body {
                background: white;
            }
            
            .invoice-container {
                max-width: none;
                width: 100%;
                margin: 0 auto;
                padding: var(--base-padding);
                border: none;
                box-shadow: none;
            }
            
            .header {
                border-bottom: 2px solid var(--border-color);
            }
            
            .product-table th {
                padding: 3mm 2mm;
            }
            
            .product-table td {
                padding: 3mm 2mm;
            }
        }
    </style>
    <link href="https://fonts.googleapis.com/css2?family=Libre+Barcode+128&display=swap" rel="stylesheet">
</head>
<body>
    <div class="invoice-container">
        <!-- Logo de fond -->
      
        
        <div class="header">
            <div class="logo-container">
                <img src="${businessDetails['logo']}" alt="${businessDetails['name']}">
            </div>
            <div class="business-name">${businessDetails['name']}</div>
            <div class="business-info">
                $locationDetails
            </div>
            <div class="business-info">
                $taxLabel: $taxNumber
            </div>
            <div class="invoice-title">FACTURE #$invoiceNo</div>
        </div>

        <div class="invoice-meta">
            <div class="meta-row">
                <span><strong>Date:</strong> $date</span>
            </div>
            <div class="meta-row">
                <span><strong>Montant dû:</strong></span>
                <span><strong>$symbol $totalAmount</strong></span>
            </div>
        </div>

        <div class="customer-info">
            <strong>Facturer à:</strong>
            $customerName<br>
            $customerAddress<br>
            $customerMobile
        </div>

        <table class="product-table">
            <thead>
                
            </thead>
            <tbody>
                $productsHtml
            </tbody>
        </table>

        <div class="totals">
            <div class="totals-row">
                <span>Sous-total:</span>
                <span>$symbol $sTotal</span>
            </div>
            $shippingHtml
            $discountHtml
            $inlineDiscountHtml
            $taxHtml
            $inlineTaxesHtml
            $returnHtml
            <div class="totals-row total-bold">
                <span>TOTAL:</span>
                <span>$symbol $totalAmount</span>
            </div>
        </div>

        <div class="totals">
            <div class="totals-row">
                <span>Montant payé:</span>
                <span>$symbol $totalPaidAmount</span>
            </div>
            $dueHtml
        </div>

        <div class="barcode-container">
            <div class="barcode">*$invoiceNo*</div>
            <div class="barcode-text">$invoiceNo</div>
        </div>

        <div class="footer">
            Merci pour votre confiance!<br>
            ${businessDetails['name']} • $userName
        </div>
    </div>
</body>
</html>
''';
  }

  String _errorInvoiceHtml(String message) {
    return '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Erreur de Facture</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            padding: 40px;
            color: #000000;
            
            text-align: center;
        }
        h1 {
            font-size: 24px;
            margin-bottom: 0;
        }
        p {
            font-size: 16px;
            margin-bottom: 0px;
        }
        .details {
           
            padding: 20px;
            border-radius: 5px;
            border-left: 4px solid #585858;
            text-align: left;
            max-width: 600px;
            margin: 0 auto;
        }
    </style>
</head>
<body>
    <h1>Erreur de Génération de Facture</h1>
    <p>Nous avons rencontré un problème lors de la génération de votre facture.</p>
    <div class="details">
        <strong>Détails de l'erreur:</strong><br>
        $message
    </div>
    <p style="margin-top: 30px; color: #7f8c8d;">
        Veuillez contacter le support si ce problème persiste.
    </p>
</body>
</html>
''';
  }

  void setTax(taxId) {
    System().get('tax').then((value) {
      value.forEach((element) {
        if (element['id'] == taxId) {
          taxName = element['name'];
          tax = double.parse(element['amount'].toString());
        }
      });
    }).catchError((e) {
      print('[ERREUR] Définition de la taxe: $e');
      taxName = 'taxRates';
      tax = 0.0;
    });
  }

  Map<String, dynamic> getTotalAmount({
    required String discountType,
    required double discountAmount,
    required String symbol
  }) {
    try {
      Map<String, dynamic> allAmounts = {
        'taxAmount': '0.00',
        'totalAmount': subTotal.toStringAsFixed(2),
        'discountAmount': 0.0,
        'discountType': 'Pas de remise'
      };

      double effectiveTax = tax.isNaN ? 0.0 : tax;

      if (discountType == "fixed") {
        allAmounts['discountType'] = "$symbol $discountAmount";
        double tAmount = subTotal - discountAmount;
        double calculatedTaxAmount = tAmount * (effectiveTax / 100);

        allAmounts['taxAmount'] = calculatedTaxAmount.toStringAsFixed(2);
        allAmounts['totalAmount'] = (tAmount + calculatedTaxAmount).toStringAsFixed(2);
        allAmounts['discountAmount'] = discountAmount;
      } else if (discountType == "percentage") {
        allAmounts['discountType'] = "$discountAmount %";
        double calculatedDiscountAmount = subTotal * (discountAmount / 100);
        double tAmount = subTotal - calculatedDiscountAmount;
        double calculatedTaxAmount = tAmount * (effectiveTax / 100);

        allAmounts['taxAmount'] = calculatedTaxAmount.toStringAsFixed(2);
        allAmounts['totalAmount'] = (tAmount + calculatedTaxAmount).toStringAsFixed(2);
        allAmounts['discountAmount'] = calculatedDiscountAmount;
      }

      return allAmounts;
    } catch (e) {
      print('[ERREUR] Calcul du montant total: $e');
      return {
        'taxAmount': '0.00',
        'totalAmount': subTotal.toStringAsFixed(2),
        'discountAmount': 0.0,
        'discountType': 'Erreur'
      };
    }
  }
}