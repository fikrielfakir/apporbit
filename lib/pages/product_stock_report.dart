import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import '../apis/product_stock_report.dart';
import '../helpers/AppTheme.dart';
import '../locale/MyLocalizations.dart';
import '../models/product_stock_report_model.dart';

class ProductStockReportScreen extends StatefulWidget {
  static const String routeName = '/ProductStockReport';
  const ProductStockReportScreen({Key? key}) : super(key: key);

  static int themeType = 1;

  @override
  State<ProductStockReportScreen> createState() => _ProductStockReportScreenState();
}

class _ProductStockReportScreenState extends State<ProductStockReportScreen> {
  ThemeData themeData = AppTheme.getThemeFromThemeMode(ProductStockReportScreen.themeType);
  CustomAppTheme customAppTheme = AppTheme.getCustomAppTheme(ProductStockReportScreen.themeType);

  List<ProductStockReportModel> myProductReportList = [];
  bool loading = true;

  Future<void> _getProductStockReport() async {
    dev.log("Start");
    setState(() => loading = true);

    try {
      var result = await ProductStockReportService().getProductStockReport();
      setState(() {
        myProductReportList = result ?? [];
        loading = false;
      });
    } catch (e) {
      setState(() {
        loading = false;
        myProductReportList = [];
      });
      dev.log("Error fetching product stock report: $e");
    }
  }

  // Helper methods for formatting values
  String _formatTotalSold(String? value) {
    final parsed = int.tryParse(value?.replaceAll(RegExp(r'[^0-9]'), '') ?? '0') ?? 0;
    return (parsed / 100).toStringAsFixed(2);
  }

  String _formatStock(String? value) {
    final parsed = int.tryParse(value?.replaceAll(RegExp(r'[^0-9]'), '') ?? '0') ?? 0;
    return (parsed / 10000).round().toString();
  }

  String _formatAlertQuantity(String? value) {
    final parsed = int.tryParse(value?.replaceAll(RegExp(r'[^0-9]'), '') ?? '0') ?? 0;
    return (parsed / 10000).round().toString();
  }

  String _formatStockPrice(String? value) {
    if (value == null || value.isEmpty) return '0.00';
    final parsed = double.tryParse(value.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
    return parsed.toStringAsFixed(2);
  }

  @override
  void initState() {
    super.initState();
    _getProductStockReport();
  }

  @override
  Widget build(BuildContext context) {
    // Initialize totals
    double totalSold = 0;
    double totalStockPrice = 0.0;
    double totalStock = 0;
    double totalUnitPrice = 0.0;
    double totalAlertQuantity = 0;

    // Calculate totals with proper formatting
    for (var item in myProductReportList) {
      try {
        totalSold += (int.tryParse(item.totalSold?.replaceAll(RegExp(r'[^0-9]'), '') ?? '0') ?? 0) / 100;
      } catch (e) {
        dev.log("Error parsing totalSold for ${item.product}: $e");
      }

      try {
        totalStockPrice += double.tryParse(item.stockPrice?.replaceAll(RegExp(r'[^0-9.]'), '') ?? '0') ?? 0;
      } catch (e) {
        dev.log("Error parsing stockPrice for ${item.product}: $e");
      }

      try {
        totalStock += (int.tryParse(item.stock?.replaceAll(RegExp(r'[^0-9]'), '') ?? '0') ?? 0) / 10000;
      } catch (e) {
        dev.log("Error parsing stock for ${item.product}: $e");
        dev.log("Problematic stock value: '${item.stock}'");
      }

      try {
        totalUnitPrice += double.tryParse(item.unitPrice?.replaceAll(RegExp(r'[^0-9.]'), '') ?? '0') ?? 0;
      } catch (e) {
        dev.log("Error parsing unitPrice for ${item.product}: $e");
      }

      try {
        totalAlertQuantity += (int.tryParse(item.alertQuantity?.replaceAll(RegExp(r'[^0-9]'), '') ?? '0') ?? 0) / 10000;
      } catch (e) {
        dev.log("Error parsing alertQuantity for ${item.product}: $e");
      }
    }

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Text(
          AppLocalizations.of(context).translate('products_stock'),
          style: AppTheme.getTextStyle(themeData.textTheme.titleLarge, fontWeight: 600),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : myProductReportList.isEmpty
          ? Center(child: Text(AppLocalizations.of(context).translate('no_data_available')))
          : Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: DataTable(
                  columnSpacing: 20,
                  headingTextStyle: textHeadStyle(context),
                  headingRowColor: MaterialStateColor.resolveWith((states) => themeData.primaryColor),
                  columns: [
                    DataColumn(label: Text(AppLocalizations.of(context).translate('product'))),
                    DataColumn(label: Text(AppLocalizations.of(context).translate('stock'))),
                    DataColumn(label: Text(AppLocalizations.of(context).translate('unit'))),
                    DataColumn(label: Text(AppLocalizations.of(context).translate('unit_pricee'))),
                    DataColumn(label: Text(AppLocalizations.of(context).translate('stock_price'))),
                    DataColumn(label: Text(AppLocalizations.of(context).translate('sku'))),
                    DataColumn(label: Text(AppLocalizations.of(context).translate('type'))),
                    DataColumn(label: Text(AppLocalizations.of(context).translate('location_nname'))),
                    DataColumn(label: Text(AppLocalizations.of(context).translate('alert_quantity'))),

                    DataColumn(label: Text(AppLocalizations.of(context).translate('total_sold'))),
                  ],
                  rows: [
                    ...myProductReportList.map((item) => DataRow(
                      cells: [
                        DataCell(Text(
                          item.product ?? '',
                          style: textStyle(context),
                        )),
                        DataCell(Text(
                          _formatStock(item.stock),
                          style: textStyle(context),
                        )),
                        DataCell(Text(
                          item.unit ?? '',
                          style: textStyle(context),
                        )),
                        DataCell(Text(
                          item.unitPrice ?? '0',
                          style: textStyle(context),
                        )),
                        DataCell(Text(
                          _formatStockPrice(item.stockPrice),
                          style: textStyle(context),
                        )),
                        DataCell(Text(
                          item.sku ?? '',
                          style: textStyle(context),
                        )),
                        DataCell(Text(
                          item.type ?? '',
                          style: textStyle(context),
                        )),
                        DataCell(Text(
                          item.locationName ?? '',
                          style: textStyle(context),
                        )),
                        DataCell(Text(
                          _formatAlertQuantity(item.alertQuantity),
                          style: textStyle(context),
                        )),
                        DataCell(Text(
                          _formatTotalSold(item.totalSold),
                          style: textStyle(context),
                        )),

                      ],
                    )).toList(),
                    DataRow(
                      color: MaterialStateColor.resolveWith((states) => Colors.red[50]!),
                      cells: [
                        DataCell(Text(
                          'TOTAL',
                          style: totalTextStyle(context),
                        )),

                        DataCell(Text(
                          totalStock.toStringAsFixed(0),
                          style: totalTextStyle(context),
                        )),

                        DataCell(Text('', style: textStyle(context))),
                        DataCell(Text('', style: textStyle(context))),

                        DataCell(Text(
                          totalStockPrice.toStringAsFixed(2),
                          style: totalTextStyle(context),
                        )),

                        DataCell(Text('', style: textStyle(context))),
                        DataCell(Text('', style: textStyle(context))),
                        DataCell(Text('', style: textStyle(context))),
                        DataCell(Text('', style: textStyle(context))),
                        DataCell(Text(
                          totalSold.toStringAsFixed(2),
                          style: totalTextStyle(context),
                        )),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  TextStyle textStyle(BuildContext context) {
    return TextStyle(
      fontSize: MediaQuery.of(context).size.width / 25,
      fontWeight: FontWeight.w500,
    );
  }

  TextStyle textHeadStyle(BuildContext context) {
    return TextStyle(
      fontSize: MediaQuery.of(context).size.width / 25,
      fontWeight: FontWeight.bold,
      color: Colors.white,
    );
  }

  TextStyle totalTextStyle(BuildContext context) {
    return TextStyle(
      fontSize: MediaQuery.of(context).size.width / 25,
      fontWeight: FontWeight.bold,
      color: Colors.green[800],
    );
  }
}