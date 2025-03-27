import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../helpers/otherHelpers.dart';
import '../locale/MyLocalizations.dart';

class SellReturnDetailScreen extends StatelessWidget {
  final Map<String, dynamic> sellReturn;

  const SellReturnDetailScreen({Key? key, required this.sellReturn}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    // Safely extract data with null checks and fallback values
    final returnParentSell = sellReturn['return_parent_sell'] ?? {};
    final customerName = sellReturn['contact_name'] ?? 'N/A';
    final sellLines = returnParentSell['sell_lines'] ?? [];
    final paymentLines = sellReturn['payment_lines'] ?? [];

    // Calculate total amount
    double totalAmount = 0;
    for (var item in sellLines) {
      final int quantity = (item['quantity_returned'] is String)
          ? (double.tryParse(item['quantity_returned'])?.toInt() ?? 0)
          : (item['quantity_returned'] ?? 0).toInt();

      final unitPrice = double.tryParse(item['unit_price']?.toString() ?? '0') ?? 0;
      totalAmount += quantity * unitPrice;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).translate('invoice')),
        elevation: 0,
        backgroundColor: Colors.pink,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () => _printPOSInvoice(context),
            tooltip: AppLocalizations.of(context).translate('finalize_n_print'),
          ),
        ],
      ),
      body: Container(
        color: Colors.grey.shade100,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInvoiceHeader(context, customerName),
              const SizedBox(height: 24),
              _buildInvoiceInfo(context, sellReturn),
              const SizedBox(height: 24),
              _buildProductsSection(context, sellLines),
              const SizedBox(height: 24),
              _buildTotalSection(context, totalAmount, sellReturn['payment_status'] ?? 'Unpaid'),
              const SizedBox(height: 24),
              if (paymentLines.isNotEmpty) _buildPaymentsSection(context, paymentLines),
              const SizedBox(height: 40),
              _buildPrintButton(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInvoiceHeader(BuildContext context, String customerName) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Company logo or icon
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.pink,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.receipt_long,
                color: Colors.white,
                size: 30,
              ),
            ),
            const SizedBox(width: 16),
            // Company and customer info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context).translate('invoice').toUpperCase(),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.pink,
                    ),
                  ),
                  const SizedBox(height: 4),

                  const SizedBox(height: 16),

                  const SizedBox(height: 4),
                  Text(
                    customerName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceInfo(BuildContext context, Map<String, dynamic> sellReturn) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context).translate('invoice_details'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.pink,
              ),
            ),
            const SizedBox(height: 16),
            _buildDetailRow(
              context,
              'invoice_no',
              sellReturn['invoice_no'] ?? 'N/A',
              Icons.receipt,
            ),
            const Divider(),
            _buildDetailRow(
              context,
              'date',
              _formatDate(sellReturn['transaction_date']),
              Icons.calendar_today,
            ),
            const Divider(),
            _buildDetailRow(
              context,
              'status',
              sellReturn['payment_status'] ?? 'N/A',
              Icons.payments,
              isStatus: true,
              status: sellReturn['payment_status'],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductsSection(BuildContext context, List<dynamic> sellLines) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context).translate('products'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.pink,
              ),
            ),
            const SizedBox(height: 16),
            // Table Header
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.pink.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Text(
                        AppLocalizations.of(context).translate('product'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      AppLocalizations.of(context).translate('qty'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      AppLocalizations.of(context).translate('price'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      AppLocalizations.of(context).translate('total'),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
              ),
            ),

            // Product rows
            if (sellLines.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  AppLocalizations.of(context).translate('no_products_found'),
                  style: const TextStyle(color: Colors.grey),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: sellLines.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = sellLines[index];
                  final product = item['product'] ?? {};
                  final productName = product['name'] ?? AppLocalizations.of(context).translate('unknown_product');

                  // Safely convert to int to prevent the type error
                  final int quantity = (item['quantity_returned'] is String)
                      ? (double.tryParse(item['quantity_returned'])?.toInt() ?? 0)
                      : (item['quantity_returned'] ?? 0).toInt();

                  final unitPrice = double.tryParse(item['unit_price']?.toString() ?? '0') ?? 0;
                  final total = quantity * unitPrice;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 16),
                            child: Text(productName),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Text(
                            quantity.toString(),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            '${unitPrice.toStringAsFixed(2)}',
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            '${total.toStringAsFixed(2)}MAD',
                            textAlign: TextAlign.right,
                          ),
                        ),
                        const SizedBox(width: 16),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalSection(BuildContext context, double totalAmount, String status) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppLocalizations.of(context).translate('subtotal'),
                  style: const TextStyle(
                    fontSize: 16,
                  ),
                ),
                Text(
                  '${totalAmount.toStringAsFixed(2)}MAD',
                  style: const TextStyle(
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppLocalizations.of(context).translate('tax'),
                  style: const TextStyle(
                    fontSize: 16,
                  ),
                ),
                Text(
                  'MAD0.00',
                  style: const TextStyle(
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const Divider(thickness: 1),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppLocalizations.of(context).translate('total'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${totalAmount.toStringAsFixed(2)}MAD',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.pink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _getStatusColor(status).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _getStatusColor(status)),
              ),
              child: Text(
                _getLocalizedStatus(context, status),
                style: TextStyle(
                  color: _getStatusColor(status),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentsSection(BuildContext context, List<dynamic> paymentLines) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context).translate('payment_history'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.pink,
              ),
            ),
            const SizedBox(height: 16),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: paymentLines.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final payment = paymentLines[index];
                final method = payment['method'] ?? 'N/A';

                // Handle potential double values in amount
                final dynamic rawAmount = payment['amount'] ?? 0;
                final double amount = rawAmount is double
                    ? rawAmount
                    : double.tryParse(rawAmount.toString()) ?? 0;

                final paidOn = _formatDate(payment['paid_on']);

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _getPaymentIcon(method),
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getLocalizedPaymentMethod(context, method),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${AppLocalizations.of(context).translate('paid_on')} $paidOn',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${amount.toStringAsFixed(2)}MAD',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrintButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _printPOSInvoice(context),
        icon: const Icon(Icons.print),
        label: Text(AppLocalizations.of(context).translate('finalize_n_print')),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.pink,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

// Helper method to build a detail row
  Widget _buildDetailRow(BuildContext context, String label, String value, IconData icon, {bool isStatus = false, String? status}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.pink.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: Colors.pink,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            '${AppLocalizations.of(context).translate(label)}:',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: isStatus
                ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _getStatusColor(status).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _getLocalizedStatus(context, status),
                style: TextStyle(
                  fontSize: 16,
                  color: _getStatusColor(status),
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
                : Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

// Helper method to get localized status
  String _getLocalizedStatus(BuildContext context, String? status) {
    if (status == null) return AppLocalizations.of(context).translate('unknown');

    switch (status.toLowerCase()) {
      case 'paid':
        return AppLocalizations.of(context).translate('paid');
      case 'partial':
        return AppLocalizations.of(context).translate('partial');
      case 'due':
        return AppLocalizations.of(context).translate('due');
      case 'unpaid':
        return AppLocalizations.of(context).translate('unpaid');
      default:
        return status;
    }
  }

// Helper method to get localized payment method
  String _getLocalizedPaymentMethod(BuildContext context, String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return AppLocalizations.of(context).translate('cash');
      case 'card':
        return AppLocalizations.of(context).translate('card');
      case 'credit card':
        return AppLocalizations.of(context).translate('credit_card');
      case 'debit card':
        return AppLocalizations.of(context).translate('debit_card');
      case 'bank transfer':
        return AppLocalizations.of(context).translate('bank_transfer');
      case 'transfer':
        return AppLocalizations.of(context).translate('transfer');
      case 'cheque':
      case 'check':
        return AppLocalizations.of(context).translate('cheque');
      default:
        return method;
    }
  }

  Color _getStatusColor(String? status) {
    if (status == null) return Colors.grey;

    switch (status.toLowerCase()) {
      case 'paid':
        return Colors.green;
      case 'partial':
        return Colors.orange;
      case 'due':
      case 'unpaid':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getPaymentIcon(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return Icons.money;
      case 'card':
      case 'credit card':
      case 'debit card':
        return Icons.credit_card;
      case 'bank transfer':
      case 'transfer':
        return Icons.account_balance;
      case 'cheque':
      case 'check':
        return Icons.fact_check;
      default:
        return Icons.payment;
    }
  }

// Helper method to format the date
  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final DateTime date = DateTime.parse(dateString);
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (e) {
      return dateString; // Return the original string if parsing fails
    }
  }
  void _printPOSInvoice(BuildContext context) async {
    try {
      // Créer un document PDF optimisé pour le papier thermique
      final pdf = pw.Document();

      // Obtenir les détails de l'entreprise
      final businessDetails = await Helper().getFormattedBusinessDetails();
      final logoPath = businessDetails['logo'] ?? Config().defaultBusinessImage;
      final businessName = businessDetails['name'] ?? 'Nom de l\'entreprise';
      final businessAddress = businessDetails['address'] ?? '';
      final businessPhone = businessDetails['phone'] ?? '';
      // Définir la devise en MAD
      const String currencySymbol = 'MAD';
      final taxLabel = businessDetails['taxLabel'] ?? '';
      final taxNumber = businessDetails['taxNumber'] ?? '';

      // Extraire les données nécessaires pour le retour
      final invoiceNo = sellReturn['invoice_no'] ?? 'N/A';
      final date = Helper().formatDate(sellReturn['transaction_date']);
      final time = sellReturn['transaction_time'] ?? DateTime.now().toString().substring(11, 16);
      final customerName = sellReturn['contact_name'] ?? 'N/A';
      final customerPhone = sellReturn['contact_mobile'] ?? '';
      final status = sellReturn['payment_status'] ?? 'Payé';

      // Extraire les détails de la vente d'origine
      final returnParentSell = sellReturn['return_parent_sell'] ?? {};
      final originalInvoiceNo = returnParentSell['invoice_no'] ?? 'N/A';
      final originalDate = Helper().formatDate(returnParentSell['transaction_date']);
      final originalTotal = returnParentSell['final_total'] ?? '0.00';

      final sellLines = returnParentSell['sell_lines'] ?? [];

      // Calculer le montant total pour le retour
      double totalAmount = 0;
      for (var item in sellLines) {
        final quantity = (item['quantity_returned'] is String)
            ? (double.tryParse(item['quantity_returned'])?.toInt() ?? 0)
            : (item['quantity_returned'] ?? 0).toInt();

        final unitPrice = double.tryParse(item['unit_price']?.toString() ?? '0') ?? 0;
        totalAmount += quantity * unitPrice;
      }

      // Formater le montant total
      final formattedTotal = Helper().formatCurrency(totalAmount);

      // Essayer de charger le logo de l'entreprise
      pw.MemoryImage? businessLogo;
      try {
        if (logoPath.isNotEmpty) {
          if (logoPath.startsWith('http')) {
            final response = await http.get(Uri.parse(logoPath));
            businessLogo = pw.MemoryImage(response.bodyBytes);
          } else {
            final file = File(logoPath);
            if (await file.exists()) {
              final bytes = await file.readAsBytes();
              businessLogo = pw.MemoryImage(bytes);
            }
          }
        }
      } catch (e) {
        print('Erreur lors du chargement du logo: $e');
      }

      // Créer la page de reçu au style POS avec un design amélioré
      pdf.addPage(
        pw.Page(
          // Le rouleau thermique a généralement une largeur étroite
          pageFormat: PdfPageFormat(
            80 * PdfPageFormat.mm, // Largeur de 80mm (standard pour les reçus thermiques)
            double.infinity,       // Hauteur dynamique basée sur le contenu
            marginAll: 5 * PdfPageFormat.mm, // Petites marges
          ),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                // En-tête de l'entreprise avec une mise en page améliorée
                if (businessLogo != null)
                  pw.Center(
                    child: pw.SizedBox(
                      width: 60,
                      height: 60,
                      child: pw.Image(businessLogo, fit: pw.BoxFit.contain),
                    ),
                  ),

                pw.SizedBox(height: 8),

                pw.Text(
                  businessName.toUpperCase(),
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 14,
                  ),
                  textAlign: pw.TextAlign.center,
                ),

                pw.SizedBox(height: 3),

                if (businessAddress.isNotEmpty)
                  pw.Text(
                    businessAddress,
                    style: const pw.TextStyle(fontSize: 9),
                    textAlign: pw.TextAlign.center,
                  ),

                if (businessPhone.isNotEmpty)
                  pw.Text(
                    'Tél: $businessPhone',
                    style: const pw.TextStyle(fontSize: 9),
                    textAlign: pw.TextAlign.center,
                  ),

                if (taxLabel.isNotEmpty && taxNumber.isNotEmpty)
                  pw.Text(
                    '$taxLabel: $taxNumber',
                    style: const pw.TextStyle(fontSize: 9),
                    textAlign: pw.TextAlign.center,
                  ),

                // Diviseur stylisé
                pw.SizedBox(height: 5),
                pw.Container(
                  height: 1,
                  color: PdfColors.grey,
                  width: double.infinity,
                ),
                pw.SizedBox(height: 5),

                // Titre du reçu avec un meilleur style
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  decoration: pw.BoxDecoration(
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
                    color: PdfColors.grey200,
                  ),
                  child: pw.Text(
                    'REÇU DE RETOUR',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 12,
                      color: PdfColors.black,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                ),

                // Détails de la facture avec un espacement amélioré
                pw.SizedBox(height: 8),
                _buildInfoRow('Reçu #:', invoiceNo),
                _buildInfoRow('Date:', '$date $time'),

                // Informations du client avec une meilleure mise en page
                if (customerName != 'N/A') ...[
                  _buildInfoRow('Client:', customerName),
                  if (customerPhone.isNotEmpty)
                    _buildInfoRow('Téléphone:', customerPhone),
                ],

                // Statut avec style
                _buildInfoRow('Statut:', status,
                  valueStyle: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: status.toLowerCase() == 'payé' ? PdfColors.black : PdfColors.grey800,
                  ),
                ),

                // Diviseur stylisé
                pw.SizedBox(height: 5),
                pw.Container(
                  height: 1,
                  color: PdfColors.grey300,
                  width: double.infinity,
                ),
                pw.SizedBox(height: 5),

                // Détails de la vente d'origine avec un en-tête amélioré
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.symmetric(vertical: 3),
                  color: PdfColors.grey100,
                  child: pw.Text(
                    'Détails de la vente d\'origine',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                pw.SizedBox(height: 5),
                _buildInfoRow('Facture d\'origine #:', originalInvoiceNo),
                _buildInfoRow('Date d\'origine:', originalDate),
                _buildInfoRow('Total d\'origine:', '${double.parse(originalTotal).toStringAsFixed(2)} $currencySymbol'),

                // Diviseur stylisé avant les articles
                pw.SizedBox(height: 5),
                pw.Container(
                  height: 1,
                  color: PdfColors.grey300,
                  width: double.infinity,
                ),
                pw.SizedBox(height: 8),

                // En-tête des articles avec un style amélioré
                pw.Container(
                  color: PdfColors.grey200,
                  padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                  child: pw.Row(
                    children: [
                      pw.Expanded(
                        flex: 5,
                        child: pw.Text(
                          'ARTICLE',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
                        ),
                      ),
                      pw.Expanded(
                        flex: 1,
                        child: pw.Text(
                          'QTY',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text(
                          'PRIX',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text(
                          'TOTAL',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ),

                // Liste des articles avec des couleurs de fond alternées
                for (var i = 0; i < sellLines.length; i++) ...[
                  pw.Container(
                    color: i % 2 == 0 ? PdfColors.white : PdfColors.grey50,
                    padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 2),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Expanded(
                          flex: 5,
                          child: pw.Text(
                            sellLines[i]['product']?['name'] ?? 'Produit inconnu',
                            style: const pw.TextStyle(fontSize: 8),
                          ),
                        ),
                        pw.Expanded(
                          flex: 1,
                          child: pw.Text(
                            Helper().formatQuantity(sellLines[i]['quantity_returned']),
                            style: const pw.TextStyle(fontSize: 8),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Expanded(
                          flex: 2,
                          child: pw.Text(
                            '${(double.tryParse(sellLines[i]['unit_price']?.toString() ?? '0') ?? 0).toStringAsFixed(2)} $currencySymbol',
                            style: const pw.TextStyle(fontSize: 8),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                        pw.Expanded(
                          flex: 2,
                          child: pw.Text(
                            '${((sellLines[i]['quantity_returned'] is String
                                ? (double.tryParse(sellLines[i]['quantity_returned']) ?? 0)
                                : (sellLines[i]['quantity_returned'] ?? 0).toDouble()) *
                                (double.tryParse(sellLines[i]['unit_price']?.toString() ?? '0') ?? 0)).toStringAsFixed(2)} $currencySymbol',
                            style: const pw.TextStyle(fontSize: 8),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Section des totaux avec un meilleur style
                pw.SizedBox(height: 5),
                pw.Container(
                  height: 1,
                  color: PdfColors.grey300,
                  width: double.infinity,
                ),
                pw.SizedBox(height: 5),

                _buildInfoRow('Sous-total:', '$formattedTotal $currencySymbol'),

                // Total avec mise en évidence
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                  color: PdfColors.grey200,
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('TOTAL:',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 10,
                          )
                      ),
                      pw.Text(
                        '$formattedTotal $currencySymbol',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),

                // Méthode de paiement
                pw.SizedBox(height: 8),
                _buildInfoRow('Méthode de paiement:', 'En espèces'),

                // Diviseur stylisé avant le pied de page
                pw.SizedBox(height: 5),
                pw.Container(
                  height: 1,
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                      bottom: pw.BorderSide(
                        color: PdfColors.grey,
                        width: 1,
                        style: pw.BorderStyle.dashed,
                      ),
                    ),
                  ),
                ),
                pw.SizedBox(height: 10),

                // Code-barres mieux stylisé
                pw.Center(
                  child: pw.BarcodeWidget(
                    barcode: pw.Barcode.code128(),
                    data: invoiceNo,
                    width: 70,
                    height: 40,
                  ),
                ),

                pw.SizedBox(height: 10),

                // Indicateur de ligne de coupe du reçu avec un meilleur style
                pw.Text(
                  '- - - - - - - - - - - - - - - - - - - - - - - - -',
                  style: const pw.TextStyle(fontSize: 10),
                  textAlign: pw.TextAlign.center,
                ),

                // Texte du pied de page
                pw.SizedBox(height: 5),

              ],
            );
          },
        ),
      );

      // Imprimer le document
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Reçu_${sellReturn['invoice_no']}.pdf',
        format: PdfPageFormat(
          110 * PdfPageFormat.mm, // Largeur de 80mm (standard pour les reçus thermiques)
          double.infinity,       // Hauteur dynamique basée sur le contenu
          marginAll: 5 * PdfPageFormat.mm, // Petites marges
        ),
      );
    } catch (e) {
      // Gérer les erreurs
      print('Erreur lors de la génération du reçu POS: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Échec de la génération du reçu: ${e.toString()}')),
      );
    }
  }

// Fonction helper pour créer des lignes d'information cohérentes
  pw.Widget _buildInfoRow(String label, String value, {pw.TextStyle? valueStyle}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
          pw.Text(
              value,
              style: valueStyle ?? const pw.TextStyle(fontSize: 9)
          ),
        ],
      ),
    );
  }
}