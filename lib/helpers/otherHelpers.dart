import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:barcode_scan2/barcode_scan2.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cron/cron.dart';
import 'package:flutter/material.dart';
import 'package:htmltopdfwidgets/htmltopdfwidgets.dart' as pd;
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config.dart';
import '../locale/MyLocalizations.dart';
import '../models/invoice.dart';
import '../models/system.dart';
import 'AppTheme.dart';
import 'SizeConfig.dart';
import '../models/database.dart';
class SyncNotification extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const SyncNotification({
    Key? key,
    required this.message,
    this.onRetry,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        width: double.infinity,
        color: Colors.red,
        child: SafeArea(
          bottom: false,
          child: Row(
            children: [
              Icon(Icons.sync_problem, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ),
              if (onRetry != null)
                TextButton(
                  style: TextButton.styleFrom(
                    primary: Colors.white,
                    backgroundColor: Colors.red[700],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  onPressed: onRetry,
                  child: Text(
                    AppLocalizations.of(context).translate('retry'),
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
class Helper {
  static int themeType = 1;
  late DbProvider dbProvider;
  ThemeData themeData = AppTheme.getThemeFromThemeMode(themeType);
  CustomAppTheme customAppTheme = AppTheme.getCustomAppTheme(themeType);

  // Display a loading indicator
  Widget loadingIndicator(BuildContext context) {
    return Center(
      child: Card(
        elevation: MySize.size10,
        child: Container(
          padding: EdgeInsets.all(MySize.size28!),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(MySize.size8!),
          ),
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }

  // Format a numeric value into a currency string
  String formatCurrency(dynamic amount) {
    try {
      double convertAmount = double.parse(amount.toString());
      return NumberFormat.currency(
        symbol: '',
        decimalDigits: Config.currencyPrecision,
      ).format(convertAmount);
    } catch (e) {
      return '0.00';
    }
  }

  // Validate and convert a string input to a double
  double validateInput(String val) {
    try {
      return double.parse(val);
    } catch (e) {
      return 0.00;
    }
  }

  // Format a numeric value into a quantity string
  String formatQuantity(dynamic amount) {
    try {
      double quantity = double.parse(amount.toString());
      return NumberFormat.currency(
        symbol: '',
        decimalDigits: Config.quantityPrecision,
      ).format(quantity);
    } catch (e) {
      return '0.00';
    }
  }

  // Create a map of arguments for passing data
  Map<String, dynamic> argument({
    int? sellId,
    int? locId,
    int? taxId,
    String? discountType,
    double? discountAmount,
    double? invoiceAmount,
    int? customerId,
    int? isQuotation,
  }) {
    return {
      'sellId': sellId,
      'locationId': locId,
      'taxId': taxId,
      'discountType': discountType,
      'discountAmount': discountAmount,
      'invoiceAmount': invoiceAmount,
      'customerId': customerId,
      'is_quotation': isQuotation,
    };
  }

  // Check internet connectivity
  Future<bool> checkConnectivity() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult == ConnectivityResult.mobile ||
        connectivityResult == ConnectivityResult.wifi ||
        connectivityResult == ConnectivityResult.ethernet;
  }

  // Get location name by ID
  Future<String> getLocationNameById(int? locationId) async {
    if (locationId == null) return "Unknown Location";

    try {
      var locations = await System().get('location');
      for (var element in locations) {
        int? id = int.tryParse(element['id']?.toString() ?? '');
        if (id != null && id == locationId) {
          return element['name'];
        }
      }
      return "Unknown Location";
    } catch (e) {
      print("Error fetching location name: $e");
      return "Unknown Location";
    }
  }

  // Calculate tax and discount amounts
  Future<Map<String, double>> calculateTaxAndDiscount({
    required double discountAmount,
    required String discountType,
    required int taxId,
    required double unitPrice,
  }) async {
    double disAmt = 0.0, tax = 0.00, taxAmt = 0.00;

    try {
      var taxes = await System().get('tax');
      for (var element in taxes) {
        if (element['id'] == taxId) {
          tax = double.parse(element['amount'].toString());
          break;
        }
      }

      if (discountType == 'fixed') {
        disAmt = discountAmount;
        taxAmt = (unitPrice - discountAmount) * tax / 100;
      } else {
        disAmt = unitPrice * discountAmount / 100;
        taxAmt = (unitPrice - (unitPrice * discountAmount / 100)) * tax / 100;
      }

      return {'discountAmount': disAmt, 'taxAmount': taxAmt};
    } catch (e) {
      print("Error calculating tax and discount: $e");
      return {'discountAmount': 0.0, 'taxAmount': 0.0};
    }
  }

  // Calculate total price including tax and discount
  Future<String> calculateTotal({
    required double unitPrice,
    required String discountType,
    required double discountAmount,
    required int taxId,
  }) async {
    try {
      double tax = 0.00;
      var taxes = await System().get('tax');
      for (var element in taxes) {
        if (element['id'] == taxId) {
          tax = double.parse(element['amount'].toString());
          break;
        }
      }

      double amount = (discountType == 'fixed')
          ? unitPrice - discountAmount
          : unitPrice - (unitPrice * discountAmount / 100);

      double subTotal = amount + (amount * tax / 100);
      return subTotal.toStringAsFixed(2);
    } catch (e) {
      print("Error calculating total: $e");
      return '0.00';
    }
  }

  // Scan a barcode
  Future<String> barcodeScan() async {
    try {
      var result = await BarcodeScanner.scan();
      return result.rawContent.trimRight();
    } catch (e) {
      print("Error scanning barcode: $e");
      return '';
    }
  }

  // Print a PDF document
  Future<void> printDocument(int sellId, int taxId, BuildContext context, {String? invoice}) async {
    try {
      final user = await System().get('loggedInUser');
      final userName = ((user['surname'] ?? "") + ' ' + user['first_name']).trim();

      String _invoice = invoice ?? await InvoiceFormatter(
        userName: userName,
      ).generateInvoice(sellId, taxId, context);

      final customPageFormat = pd.PdfPageFormat(311, 792); // 110mm width

      await Printing.layoutPdf(
        format: customPageFormat,
        onLayout: (format) async {
          return await Printing.convertHtml(
            format: customPageFormat, // keep consistent with layoutPdf
            html: _invoice,
          );
        },
      );
    } catch (e) {
      print("Error printing document: $e");
    }
  }


  // Request app permissions
  Future<Map<Permission, PermissionStatus>> requestAppPermission() async {
    return await [
      Permission.location,
      Permission.storage,
      Permission.camera,
    ].request();
  }

  // Schedule a recurring task
  void jobScheduler() {
    if (Config().syncCallLog) {
      final cron = Cron();
      cron.schedule(
        Schedule.parse('*/${Config.callLogSyncDuration} * * * *'),
            () async {
          await syncCallLogs();
        },
      );
    }
  }

  // Sync call logs with the server
  Future<void> syncCallLogs() async {
    if (await Permission.phone.status == PermissionStatus.granted) {
      if (Config().syncCallLog && await checkConnectivity()) {
        try {
          // Fetch and sync call logs
        } catch (e) {
          print("Error syncing call logs: $e");
        }
      }
    }
  }

  // Save and share a PDF invoice
  Future<void> savePdf(int sellId, int taxId, BuildContext context, String invoiceNo, {String? invoice}) async {
    try {
      // Get user data
      final user = await System().get('loggedInUser');
      final userName = ((user['surname'] != null) ? user['surname'] : "") + ' ' + user['first_name'];

      // Generate invoice HTML
      String _invoice = invoice ?? await InvoiceFormatter(
          userName: userName
      ).generateInvoice(sellId, taxId, context);
      var targetPath = await getTemporaryDirectory();
      var targetFileName = "invoice_no_${Random().nextInt(100)}.pdf";
      final String path = '${targetPath.path}/$targetFileName';
      final pdfDocument = await Printing.convertHtml(
        format: pd.PdfPageFormat(555.44, 841),
        html: _invoice,
      );
      await File(path).writeAsBytes(pdfDocument);
      await Printing.sharePdf(bytes: pdfDocument, filename: targetFileName);
    } catch (e) {
      print("Error saving PDF: $e");
    }
  }

  // Fetch formatted business details
  Future<Map<String, dynamic>> getFormattedBusinessDetails() async {
    try {
      List business = await System().get('business');
      return {
        'symbol': business[0]['currency']['symbol'] ?? '',
        'name': business[0]['name'] ?? '',
        'logo': business[0]['logo'] ?? Config().defaultBusinessImage,
        'currencyPrecision': business[0]['currency_precision'] ?? Config.currencyPrecision,
        'quantityPrecision': business[0]['quantity_precision'] ?? Config.quantityPrecision,
        'taxLabel': business[0]['tax_label_1'] ?? '',
        'taxNumber': business[0]['tax_number_1'] ?? '',
      };
    } catch (e) {
      print("Error fetching business details: $e");
      return {
        'symbol': '',
        'name': '',
        'logo': Config().defaultBusinessImage,
        'currencyPrecision': Config.currencyPrecision,
        'quantityPrecision': Config.quantityPrecision,
        'taxLabel': '',
        'taxNumber': '',
      };
    }
  }

  // Check if the user has a specific permission
  Future<bool> getPermission(String permissionFor) async {
    try {
      var permissions = await System().getPermission();
      return permissions[0] == 'all' || permissions.contains(permissionFor);
    } catch (e) {
      print("Error fetching permission: $e");
      return false;
    }
  }

  // Display a dropdown for calling or messaging
  Widget callDropdown(BuildContext context, followUpDetails, List<String> numbers, {required String type}) {
    numbers.removeWhere((element) => element == 'null');
    return Container(
      height: MySize.size36,
      child: PopupMenuButton<String>(
        icon: Icon(
          type == 'call' ? MdiIcons.phone : MdiIcons.whatsapp,
          color: type == 'call' ? themeData.colorScheme.primary : Colors.green,
        ),
        onSelected: (value) async {
          if (type == 'call') {
            await launch('tel:$value');
          } else if (type == 'whatsApp') {
            await launch("https://wa.me/$value");
          }
        },
        itemBuilder: (BuildContext context) {
          return numbers.map((item) {
            return PopupMenuItem<String>(
              value: item,
              child: Text(
                item,
                style: TextStyle(color: Colors.black),
              ),
            );
          }).toList();
        },
      ),
    );
  }

  // Display a widget indicating no data is available
  Widget noDataWidget(BuildContext context) {
    return Column(
      children: [
        Expanded(
          flex: 5,
          child: CachedNetworkImage(
            imageUrl: Config().noDataImage,
            errorWidget: (context, url, error) =>
                Lottie.asset('assets/lottie/empty.json'),
          ),
        ),
        Expanded(
          flex: 1,
          child: Text(
            AppLocalizations.of(context).translate('no_data'),
            style: AppTheme.getTextStyle(
              themeData.textTheme.headline5,
              fontWeight: 600,
              color: themeData.colorScheme.onBackground,
            ),
          ),
        ),
      ],
    );
  }


  String formatDate(String dateString) {
    try {
      final DateTime date = DateTime.parse(dateString);
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (e) {
      return dateString;
    }
  }

  // In helpers/otherHelpers.dart
  static double validateReturnAmount(String value, double maxAmount) {
    double amount = double.tryParse(value) ?? 0.0;
    return amount > maxAmount ? maxAmount : amount;
  }

  static String getCurrencySymbol() {
    // You can replace this with your actual currency symbol logic
    // For example, you might get it from app settings or localization
    return 'MAD'; // Default to Indian Rupee symbol
    // Or you could use: return '€'; for Euro
    // Or return '\$'; for Dollar
  }
}