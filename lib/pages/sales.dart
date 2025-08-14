import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:pos_final/config.dart';
import 'package:search_choices/search_choices.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../apis/api.dart';
import '../apis/sell.dart';
import '../helpers/AppTheme.dart';
import '../helpers/SizeConfig.dart';
import '../helpers/otherHelpers.dart';
import '../locale/MyLocalizations.dart';
import '../models/contact_model.dart';
import '../models/paymentDatabase.dart';
import '../models/sell.dart';
import '../models/sellDatabase.dart';
import '../models/system.dart';
import 'elements.dart';
import './add_sell_return_screen.dart';
import './sell_return_list_screen.dart';

class Sales extends StatefulWidget {
  @override
  _SalesState createState() => _SalesState();
}

class _SalesState extends State<Sales> with TickerProviderStateMixin {
  List sellList = [];
  List<String> paymentStatuses = ['all'], invoiceStatuses = ['final', 'draft'];
  ScrollController _scrollController = new ScrollController();
  bool isLoading = false,
      synced = true,
      canViewSell = false,
      canEditSell = false,
      canDeleteSell = false,
      showFilter = false,
      changeUrl = false;
  Map<dynamic, dynamic> selectedLocation = {'id': 0, 'name': 'All'},
      selectedCustomer = {'id': 0, 'name': 'All', 'mobile': ''};
  String selectedPaymentStatus = '';
  String? startDateRange, endDateRange;
  List<Map<dynamic, dynamic>> allSalesListMap = [],
      customerListMap = [
        {'id': 0, 'name': 'All', 'mobile': ''}
      ],
      locationListMap = [
        {'id': 0, 'name': 'All'}
      ];
  String symbol = '';
  String? nextPage = '', url = Api().baseUrl + Api().apiUrl + "/sell?order_by_date=desc";
  static int themeType = 1;
  ThemeData themeData = AppTheme.getThemeFromThemeMode(themeType);
  CustomAppTheme customAppTheme = AppTheme.getCustomAppTheme(themeType);

  List<Map<String, dynamic>> selectedProducts = [];
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    setCustomers();
    setLocations();
    if ((synced)) refreshSales();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels ==
          _scrollController.position.maxScrollExtent) {
        setAllSalesList();
      }
    });
    Helper().syncCallLogs();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _tabController?.dispose();
    super.dispose();
  }

  void fetchProductsForSell(int sellId) async {
    setState(() {
      isLoading = true;
    });

    var products = await SellDatabase().getProductsBySellId(sellId);
    setState(() {
      selectedProducts = products;
      isLoading = false;
    });
  }

  setCustomers() async {
    customerListMap.addAll(await Contact().get());
    setState(() {});
  }

  setLocations() async {
    if (!mounted) return;

    try {
      // Initialize with default "All" option if empty
      if (locationListMap.isEmpty) {
        locationListMap = [{'id': 0, 'name': 'All'}];
        selectedLocation = locationListMap.first;
      }

      final locations = await System().get('location');
      if (!mounted) return;

      // Use a Map to ensure uniqueness by ID
      final Map<dynamic, Map<dynamic, dynamic>> uniqueLocations = {
        0: {'id': 0, 'name': 'All'} // Always include the default "All" option
      };

      // Add locations from the system, avoiding duplicates
      for (var element in locations) {
        final id = element['id'];
        if (id != null && id != 0) { // Don't override the "All" option
          uniqueLocations[id] = {
            'id': id,
            'name': element['name'] ?? 'Unknown Location',
          };
        }
      }

      if (!mounted) return;

      // Convert back to list
      final newLocationList = uniqueLocations.values.toList();

      // Update state
      setState(() {
        locationListMap = newLocationList;

        // Ensure selectedLocation is still valid
        bool selectedExists = locationListMap.any((location) =>
        location['id'] == selectedLocation['id']);

        if (!selectedExists) {
          selectedLocation = locationListMap.first; // Default to "All"
        }
      });

      // Handle permissions
      await System().refreshPermissionList();
      if (!mounted) return;

      await getPermission();
      if (!mounted) return;

      setState(() {
        changeUrl = true;
      });
      onFilter();

    } catch (e) {
      print('Error in setLocations: $e');
      // Ensure we have at least the default "All" option
      if (mounted) {
        setState(() {
          if (locationListMap.isEmpty) {
            locationListMap = [{'id': 0, 'name': 'All'}];
            selectedLocation = locationListMap.first;
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_tabController == null) {
      return Scaffold(


        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    bool hasUnsyncedInvoices = sellList.any((sell) => sell['is_synced'] == 0);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return <Widget>[
            SliverAppBar(
              elevation: 0,
              floating: true,
              pinned: true,
              snap: false,
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              title: Text(
                AppLocalizations.of(context).translate('sales'),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              actions: [
                _buildSyncButton(),
                SizedBox(width: 8),
              ],
              bottom: PreferredSize(
                preferredSize: Size.fromHeight(
                  hasUnsyncedInvoices ? 100.0 : 48.0,
                ),
                child: Column(
                  children: [
                    if (hasUnsyncedInvoices) _buildSyncBanner(),
                    _buildTabBar(),
                  ],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController!,
          children: [
            _buildRecentSalesTab(),
            _buildAllSalesTab(),
            SellReturnListScreen(),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncButton() {
    return Container(
      margin: EdgeInsets.only(right: 8),
      child: IconButton(
        onPressed: _handleSync,
        icon: AnimatedSwitcher(
          duration: Duration(milliseconds: 300),
          child: isLoading
              ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          )
              : Icon(
            MdiIcons.syncIcon,
            color: Colors.white,
            size: 24,
          ),
        ),
        tooltip: AppLocalizations.of(context).translate('sync'),
      ),
    );
  }

  Widget _buildSyncBanner() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.orange.shade100,
      child: Row(
        children: [
          Icon(MdiIcons.syncAlert, color: Colors.orange.shade700, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              AppLocalizations.of(context).translate('invoice_not_synced'),
              style: TextStyle(
                color: Colors.orange.shade700,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: _handleSync,
            child: Text(
              AppLocalizations.of(context).translate('sync_now'),
              style: TextStyle(
                color: Colors.orange.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Theme.of(context).primaryColor,
      child: TabBar(
        controller: _tabController!,
        indicatorColor: Colors.white,
        indicatorWeight: 3,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        labelStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        tabs: [
          Tab(
            icon: Icon(MdiIcons.clockOutline, size: 20),
            text: AppLocalizations.of(context).translate('recent'),
          ),
          Tab(
            icon: Icon(MdiIcons.chartLine, size: 20),
            text: AppLocalizations.of(context).translate('all_sales'),
          ),
          Tab(
            icon: Icon(MdiIcons.arrowLeftBold, size: 20),
            text: AppLocalizations.of(context).translate('returns'),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentSalesTab() {
    if (sellList.isEmpty) {
      return _buildEmptyState(
        icon: MdiIcons.receiptTextOutline,
        title: AppLocalizations.of(context).translate('no_recent_sales'),
        subtitle: AppLocalizations.of(context).translate('start_making_sales'),
      );
    }

    return RefreshIndicator(
      onRefresh: () => refreshSales(),
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: sellList.length,
        itemBuilder: (context, index) => _buildRecentSaleCard(index),
      ),
    );
  }

  Widget _buildAllSalesTab() {
    if (!canViewSell) {
      return _buildEmptyState(
        icon: MdiIcons.lockOutline,
        title: AppLocalizations.of(context).translate('unauthorised'),
        subtitle: AppLocalizations.of(context).translate('no_permission'),
      );
    }

    return Column(
      children: [
        _buildFilterSection(),
        Expanded(
          child: allSalesListMap.isEmpty
              ? _buildEmptyState(
            icon: MdiIcons.databaseSearchOutline,
            title: AppLocalizations.of(context).translate('no_sales_found'),
            subtitle: AppLocalizations.of(context).translate('adjust_filters'),
          )
              : RefreshIndicator(
            onRefresh: () => _refreshAllSales(),
            child: ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.all(16),
              itemCount: allSalesListMap.length + (isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == allSalesListMap.length) {
                  return _buildLoadingIndicator();
                }
                return _buildAllSaleCard(index);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterSection() {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      margin: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                showFilter = !showFilter;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        MdiIcons.filterVariant,
                        color: Theme.of(context).primaryColor,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        AppLocalizations.of(context).translate('filters'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ],
                  ),
                  AnimatedRotation(
                    turns: showFilter ? 0.5 : 0,
                    duration: Duration(milliseconds: 300),
                    child: Icon(
                      MdiIcons.chevronDown,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: Duration(milliseconds: 300),
            child: showFilter ? _buildFilterContent() : SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterContent() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          Divider(height: 1),
          SizedBox(height: 16),
          _buildFilterRow(
            label: AppLocalizations.of(context).translate('location'),
            child: _buildLocationDropdown(),
          ),
          SizedBox(height: 16),
          _buildFilterRow(
            label: AppLocalizations.of(context).translate('customer'),
            child: _buildCustomerDropdown(),
          ),
          SizedBox(height: 16),
          _buildDateRangeSelector(),
          SizedBox(height: 16),
          _buildFilterRow(
            label: AppLocalizations.of(context).translate('payment_status'),
            child: _buildPaymentStatusDropdown(),
          ),
          SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _resetFilters,
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(AppLocalizations.of(context).translate('reset')),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onFilter,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(AppLocalizations.of(context).translate('apply')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow({required String label, required Widget child}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            '$label:',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
        ),
        SizedBox(width: 12),
        Expanded(child: child),
      ],
    );
  }

  Widget _buildDateRangeSelector() {
    return InkWell(
      onTap: () => _showDateRangePicker(),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(MdiIcons.calendarRange, size: 20, color: Colors.grey[600]),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                (startDateRange != null && endDateRange != null)
                    ? '$startDateRange - $endDateRange'
                    : AppLocalizations.of(context).translate('select_date_range'),
                style: TextStyle(
                  color: (startDateRange != null && endDateRange != null)
                      ? Colors.black87
                      : Colors.grey[600],
                ),
              ),
            ),
            Icon(MdiIcons.chevronDown, size: 20, color: Colors.grey[600]),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentSaleCard(int index) {
    final sale = sellList[index];
    final isQuotation = sale['is_quotation'] == 1;
    final status = isQuotation ? 'quotation' : checkStatus(
      sale['invoice_amount'],
      sale['pending_amount'],
    );

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      sale['transaction_date'],
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Row(
                      children: [
                        _buildStatusBadge(status, isQuotation),
                        if (sale['is_synced'] == 0) ...[
                          SizedBox(width: 8),
                          Icon(
                            MdiIcons.syncAlert,
                            size: 16,
                            color: Colors.orange,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Text(
                  isQuotation
                      ? '${AppLocalizations.of(context).translate('ref_no')} ${sale['invoice_no']}'
                      : '${AppLocalizations.of(context).translate('invoice_no')} ${sale['invoice_no']}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 8),
                _buildAmountRow(
                  AppLocalizations.of(context).translate('total_amount'),
                  '$symbol ${Helper().formatCurrency(sale['invoice_amount'])}',
                  isImportant: true,
                ),
                if (!isQuotation)
                  _buildAmountRow(
                    AppLocalizations.of(context).translate('paid_amount'),
                    '$symbol ${Helper().formatCurrency(sale['invoice_amount'] - sale['pending_amount'])}',
                  ),
                SizedBox(height: 8),
                _buildInfoRow(
                  AppLocalizations.of(context).translate('customer'),
                  sale['customer_name'],
                ),
                _buildInfoRow(
                  AppLocalizations.of(context).translate('location'),
                  sale['location_name'],
                ),
              ],
            ),
          ),
          _buildActionBar(sale, index, isRecent: true),
        ],
      ),
    );
  }

  Widget _buildAllSaleCard(int index) {
    final sale = allSalesListMap[index];
    final isQuotation = int.parse(sale['is_quotation'].toString()) == 1;

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      sale['date_time'],
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    _buildStatusBadge(sale['status'], isQuotation),
                  ],
                ),
                SizedBox(height: 12),
                Text(
                  isQuotation
                      ? '${AppLocalizations.of(context).translate('ref_no')} ${sale['invoice_no']}'
                      : '${AppLocalizations.of(context).translate('invoice_no')} ${sale['invoice_no']}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 8),
                _buildAmountRow(
                  AppLocalizations.of(context).translate('total_amount'),
                  '$symbol ${sale['invoice_amount']}',
                  isImportant: true,
                ),
                if (!isQuotation)
                  _buildAmountRow(
                    AppLocalizations.of(context).translate('paid_amount'),
                    '$symbol ${sale['paid_amount']}',
                  ),
                SizedBox(height: 8),
                _buildInfoRow(
                  AppLocalizations.of(context).translate('customer'),
                  sale['contact_name'],
                ),
                _buildInfoRow(
                  AppLocalizations.of(context).translate('location'),
                  sale['location_name'],
                ),
              ],
            ),
          ),
          _buildAllSaleActionBar(sale, index),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status, bool isQuotation) {
    Color backgroundColor;
    Color textColor = Colors.white;
    String displayText = status.toUpperCase();

    if (isQuotation) {
      backgroundColor = Colors.orange;
      displayText = 'QUOTATION';
    } else {
      switch (status.toLowerCase()) {
        case 'paid':
          backgroundColor = Colors.green;
          break;
        case 'due':
          backgroundColor = Colors.red;
          break;
        case 'partial':
          backgroundColor = Colors.orange;
          break;
        default:
          backgroundColor = Colors.grey;
      }
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        displayText,
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildAmountRow(String label, String amount, {bool isImportant = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              color: isImportant ? Theme.of(context).primaryColor : Colors.black87,
              fontSize: isImportant ? 14 : 13,
              fontWeight: isImportant ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.black87,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar(Map sale, int index, {bool isRecent = false}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
      ),
      child: Row(
        children: [
          if (canEditSell)
            _buildActionButton(
              icon: MdiIcons.pencilOutline,
              color: Theme.of(context).primaryColor,
              onPressed: () => _editSale(sale),
            ),
          if (canDeleteSell)
            _buildActionButton(
              icon: MdiIcons.deleteOutline,
              color: Colors.red,
              onPressed: () => _deleteSaleConfirmation(sale, index),
            ),
          _buildActionButton(
            icon: MdiIcons.printerWireless,
            color: Colors.deepPurple,
            onPressed: () => _printInvoice(sale),
          ),
          _buildActionButton(
            icon: MdiIcons.shareVariant,
            color: Colors.blue,
            onPressed: () => _shareInvoice(sale),
          ),
          if (sale['pending_amount'] != null && sale['pending_amount'] > 0 && canEditSell)
            _buildActionButton(
              icon: MdiIcons.creditCardOutline,
              color: Colors.green,
              onPressed: () => _makePayment(sale),
            ),
          if (sale['mobile'] != null)
            _buildActionButton(
              icon: MdiIcons.phone,
              color: Colors.green,
              onPressed: () => _makeCall(sale['mobile']),
            ),
          _buildActionButton(
            icon: MdiIcons.keyboardReturn,
            color: Colors.orange,
            onPressed: () => _createReturn(sale),
          ),
        ],
      ),
    );
  }

  Widget _buildAllSaleActionBar(Map sale, int index) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
      ),
      child: Row(
        children: [
          if (canEditSell)
            _buildActionButton(
              icon: MdiIcons.pencilOutline,
              color: Theme.of(context).primaryColor,
              onPressed: () => _editAllSale(sale),
            ),
          if (canDeleteSell)
            _buildActionButton(
              icon: MdiIcons.deleteOutline,
              color: Colors.red,
              onPressed: () => _deleteAllSaleConfirmation(sale, index),
            ),
          if (sale['invoice_url'] != null)
            _buildActionButton(
              icon: MdiIcons.printerWireless,
              color: Colors.deepPurple,
              onPressed: () => _printAllSaleInvoice(sale),
            ),
          if (sale['invoice_url'] != null)
            _buildActionButton(
              icon: MdiIcons.shareVariant,
              color: Colors.blue,
              onPressed: () => _shareAllSaleInvoice(sale),
            ),
          if (sale['mobile'] != null && sale['status'].toString().toLowerCase() != 'paid')
            _buildActionButton(
              icon: MdiIcons.phone,
              color: Colors.green,
              onPressed: () => _makeCall(sale['mobile']),
            ),
          _buildActionButton(
            icon: MdiIcons.keyboardReturn,
            color: Colors.orange,
            onPressed: () => _createAllSaleReturn(sale),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onPressed,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Icon(
            icon,
            size: 20,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      padding: EdgeInsets.all(20),
      child: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildLocationDropdown() {
    // Ensure locationListMap is not empty
    if (locationListMap.isEmpty) {
      locationListMap = [{'id': 0, 'name': 'All'}];
      selectedLocation = locationListMap.first;
    }

    // Remove duplicates based on ID
    final Map<dynamic, Map<dynamic, dynamic>> uniqueLocationsMap = {};
    for (var location in locationListMap) {
      uniqueLocationsMap[location['id']] = location;
    }
    locationListMap = uniqueLocationsMap.values.toList();

    // Ensure selectedLocation exists in the cleaned list
    bool selectedExists = locationListMap.any((location) =>
    location['id'] == selectedLocation['id']);

    if (!selectedExists) {
      selectedLocation = locationListMap.first;
    }

    // Use string values instead of Map objects for the dropdown
    String selectedValue = "${selectedLocation['id']}_${selectedLocation['name']}";

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedValue,
          isExpanded: true,
          icon: Icon(MdiIcons.chevronDown, size: 20),
          items: locationListMap.map((location) {
            String itemValue = "${location['id']}_${location['name']}";
            return DropdownMenuItem<String>(
              value: itemValue,
              child: Text(
                location['name'] ?? 'Unknown',
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null && mounted) {
              // Parse the selected value back to find the location
              List<String> parts = value.split('_');
              if (parts.length >= 2) {
                dynamic locationId;
                // Try to parse as int first, fallback to string
                try {
                  locationId = int.parse(parts[0]);
                } catch (e) {
                  locationId = parts[0];
                }

                var foundLocation = locationListMap.firstWhere(
                      (location) => location['id'] == locationId,
                  orElse: () => locationListMap.first,
                );

                setState(() {
                  selectedLocation = foundLocation;
                });
              }
            }
          },
        ),
      ),
    );
  }

  Widget _buildCustomerDropdown() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SearchChoices.single(
        underline: SizedBox.shrink(),
        displayClearIcon: false,
        value: jsonEncode(selectedCustomer),
        isExpanded: true,
        items: customerListMap.map<DropdownMenuItem<String>>((customer) {
          return DropdownMenuItem<String>(
            value: jsonEncode(customer),
            child: Text(
              "${customer['name']} (${customer['mobile'] ?? '-'})",
              overflow: TextOverflow.ellipsis,
            ),
          );
        }).toList(),
        onChanged: (value) {
          setState(() {
            selectedCustomer = jsonDecode(value);
          });
        },
      ),
    );
  }

  Widget _buildPaymentStatusDropdown() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedPaymentStatus.isEmpty ? paymentStatuses.first : selectedPaymentStatus,
          isExpanded: true,
          icon: Icon(MdiIcons.chevronDown, size: 20),
          items: paymentStatuses.map((status) {
            return DropdownMenuItem<String>(
              value: status,
              child: Text(
                AppLocalizations.of(context).translate(status).toUpperCase(),
              ),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              selectedPaymentStatus = value!;
            });
          },
        ),
      ),
    );
  }

  // Action methods
  void _handleSync() async {
    if (await Helper().checkConnectivity()) {
      setState(() => isLoading = true);
      await Sell().createApiSell(syncAll: true);
      if (mounted) {
        setState(() {
          synced = true;
          isLoading = false;
        });
        sells();
      }
    } else {
      Fluttertoast.showToast(
        msg: AppLocalizations.of(context).translate('check_connectivity'),
      );
    }
  }

  void _showDateRangePicker() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => _buildDateRangePickerScreen(),
        fullscreenDialog: true,
      ),
    );
  }

  Widget _buildDateRangePickerScreen() {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).translate('select_range')),
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: SfDateRangePicker(
              view: DateRangePickerView.month,
              selectionMode: DateRangePickerSelectionMode.range,
              onSelectionChanged: (DateRangePickerSelectionChangedArgs args) {
                if (args.value.startDate != null) {
                  setState(() {
                    startDateRange = DateFormat('yyyy-MM-dd')
                        .format(args.value.startDate)
                        .toString();
                  });
                }
                if (args.value.endDate != null) {
                  setState(() {
                    endDateRange = DateFormat('yyyy-MM-dd')
                        .format(args.value.endDate)
                        .toString();
                  });
                }
              },
            ),
          ),
          Container(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        startDateRange = null;
                        endDateRange = null;
                      });
                      Navigator.pop(context);
                    },
                    child: Text(AppLocalizations.of(context).translate('reset')),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(AppLocalizations.of(context).translate('ok')),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _resetFilters() {
    setState(() {
      selectedLocation = locationListMap[0];
      selectedCustomer = customerListMap[0];
      startDateRange = null;
      endDateRange = null;
      selectedPaymentStatus = paymentStatuses[0];
    });
    onFilter();
  }

  Future<void> _refreshAllSales() async {
    setState(() {
      allSalesListMap.clear();
      changeUrl = true;
    });
    onFilter();
  }

  // Action implementations
  void _editSale(Map sale) {
    Navigator.pushNamed(context, '/cart',
        arguments: Helper().argument(
            locId: sale['location_id'],
            sellId: sale['id'],
            isQuotation: sale['is_quotation']));
  }

  void _editAllSale(Map sale) {
    Navigator.pushNamed(context, '/cart',
        arguments: Helper().argument(
            locId: sale['location_id'],
            sellId: sale['id'],
            isQuotation: int.parse(sale['is_quotation'].toString())));
  }

  void _deleteSaleConfirmation(Map sale, int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(MdiIcons.alertCircle, color: Colors.red, size: 40),
        title: Text(AppLocalizations.of(context).translate('delete_sale')),
        content: Text(AppLocalizations.of(context).translate('are_you_sure')),
        actions: [
          TextButton(
            child: Text(AppLocalizations.of(context).translate('cancel')),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: Text(AppLocalizations.of(context).translate('delete')),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              await SellDatabase().deleteSell(sale['id']);
              if (sale['transaction_id'] != null) {
                await SellApi().delete(sale['transaction_id']);
              }
              sells();
            },
          ),
        ],
      ),
    );
  }

  void _deleteAllSaleConfirmation(Map sale, int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(MdiIcons.alertCircle, color: Colors.red, size: 40),
        title: Text(AppLocalizations.of(context).translate('delete_sale')),
        content: Text(AppLocalizations.of(context).translate('are_you_sure')),
        actions: [
          TextButton(
            child: Text(AppLocalizations.of(context).translate('cancel')),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: Text(AppLocalizations.of(context).translate('delete')),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              final response = await SellApi().delete(sale['id']);
              if (response != null) {
                setState(() => allSalesListMap.removeAt(index));
                Fluttertoast.showToast(msg: response['msg']);
              }
            },
          ),
        ],
      ),
    );
  }

  void _printInvoice(Map sale) async {
    if (await Helper().checkConnectivity() && sale['invoice_url'] != null) {
      final response = await http.Client().get(Uri.parse(sale['invoice_url']));
      if (response.statusCode == 200) {
        await Helper().printDocument(
            sale['id'], sale['tax_rate_id'], context,
            invoice: response.body);
      } else {
        await Helper().printDocument(sale['id'], sale['tax_rate_id'], context);
      }
    } else {
      await Helper().printDocument(sale['id'], sale['tax_rate_id'], context);
    }
  }

  void _printAllSaleInvoice(Map sale) async {
    if (!await Helper().checkConnectivity()) {
      Fluttertoast.showToast(
          msg: AppLocalizations.of(context).translate('check_connectivity'));
      return;
    }

    final response = await http.Client().get(Uri.parse(sale['invoice_url']));
    if (response.statusCode == 200) {
      await Helper().printDocument(0, 0, context, invoice: response.body);
    } else {
      Fluttertoast.showToast(
          msg: AppLocalizations.of(context).translate('something_went_wrong'));
    }
  }

  void _shareInvoice(Map sale) async {
    if (await Helper().checkConnectivity() && sale['invoice_url'] != null) {
      final response = await http.Client().get(Uri.parse(sale['invoice_url']));
      if (response.statusCode == 200) {
        await Helper().savePdf(sale['id'], sale['tax_rate_id'], context,
            sale['invoice_no'],
            invoice: response.body);
      } else {
        await Helper().savePdf(
            sale['id'], sale['tax_rate_id'], context, sale['invoice_no']);
      }
    } else {
      await Helper().savePdf(
          sale['id'], sale['tax_rate_id'], context, sale['invoice_no']);
    }
  }

  void _shareAllSaleInvoice(Map sale) async {
    if (!await Helper().checkConnectivity()) {
      Fluttertoast.showToast(
          msg: AppLocalizations.of(context).translate('check_connectivity'));
      return;
    }

    final response = await http.Client().get(Uri.parse(sale['invoice_url']));
    if (response.statusCode == 200) {
      await Helper().savePdf(0, 0, context, sale['invoice_no'],
          invoice: response.body);
    } else {
      Fluttertoast.showToast(
          msg: AppLocalizations.of(context).translate('something_went_wrong'));
    }
  }

  void _makePayment(Map sale) {
    Navigator.pushNamed(context, '/checkout',
        arguments: Helper().argument(
            invoiceAmount: sale['invoice_amount'],
            customerId: sale['contact_id'],
            locId: sale['location_id'],
            discountAmount: sale['discount_amount'],
            discountType: sale['discount_type'],
            isQuotation: sale['is_quotation'],
            taxId: sale['tax_rate_id'],
            sellId: sale['id']));
  }

  void _makeCall(String mobile) async {
    await launch('tel:$mobile');
  }

  void _createReturn(Map sale) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SellReturn(saleId: sale['id']),
      ),
    );
  }

  void _createAllSaleReturn(Map sale) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SellReturn(saleId: sale['id']),
      ),
    );
  }

  // Existing methods (keeping the same logic but simplified calls)
  getPermission() async {
    var activeSubscriptionDetails = await System().get('active-subscription');
    if (activeSubscriptionDetails.length > 0) {
      if (await Helper().getPermission("sell.update")) {
        canEditSell = true;
      }
      if (await Helper().getPermission("sell.delete")) {
        canDeleteSell = true;
      }
    }
    if (await Helper().getPermission("view_paid_sells_only")) {
      paymentStatuses.add('paid');
      selectedPaymentStatus = 'paid';
    }
    if (await Helper().getPermission("view_due_sells_only")) {
      paymentStatuses.add('due');
      selectedPaymentStatus = 'due';
    }
    if (await Helper().getPermission("view_partial_sells_only")) {
      paymentStatuses.add('partial');
      selectedPaymentStatus = 'partial';
    }
    if (await Helper().getPermission("view_overdue_sells_only")) {
      paymentStatuses.add('overdue');
      selectedPaymentStatus = 'all';
    }
    if (await Helper().getPermission("direct_sell.view")) {
      url = Api().baseUrl + Api().apiUrl + "/sell?order_by_date=desc";
      if (paymentStatuses.length < 2) {
        paymentStatuses.addAll(['paid', 'due', 'partial', 'overdue']);
        selectedPaymentStatus = 'all';
      }
      if (mounted) {
        setState(() {
          canViewSell = true;
        });
      }
    } else if (await Helper().getPermission("view_own_sell_only")) {
      url = Api().baseUrl + Api().apiUrl + "/sell?order_by_date=desc&user_id=${Config.userId}";
      if (paymentStatuses.length < 2) {
        paymentStatuses.addAll(['paid', 'due', 'partial', 'overdue']);
        selectedPaymentStatus = 'all';
      }
      if (mounted) {
        setState(() {
          canViewSell = true;
        });
      }
    }
  }

  refreshSales() async {
    if (await Helper().checkConnectivity()) {
      setState(() => isLoading = true);
      sells();
      setState(() => isLoading = false);
    } else {
      sells();
      Fluttertoast.showToast(
          msg: AppLocalizations.of(context).translate('check_connectivity'));
    }
  }

  sells() async {
    sellList = [];
    await SellDatabase().getSells(all: true).then((value) {
      value.forEach((element) async {
        if (element['is_synced'] == 0) if (mounted) {
          setState(() {
            synced = false;
          });
        }
        var customerDetail =
        await Contact().getCustomerDetailById(element['contact_id']);
        var locationName =
        await Helper().getLocationNameById(element['location_id']);
        if (mounted) {
          setState(() {
            sellList.add({
              'id': element['id'],
              'transaction_date': element['transaction_date'],
              'invoice_no': element['invoice_no'],
              'customer_name': customerDetail['name'],
              'mobile': customerDetail['mobile'],
              'contact_id': element['contact_id'],
              'location_id': element['location_id'],
              'location_name': locationName,
              'status': element['status'],
              'tax_rate_id': element['tax_rate_id'],
              'discount_amount': element['discount_amount'],
              'discount_type': element['discount_type'],
              'sale_note': element['sale_note'],
              'staff_note': element['staff_note'],
              'invoice_amount': element['invoice_amount'],
              'pending_amount': element['pending_amount'],
              'is_synced': element['is_synced'],
              'is_quotation': element['is_quotation'],
              'invoice_url': element['invoice_url'],
              'transaction_id': element['transaction_id']
            });
          });
        }
      });
    });
    await Helper().getFormattedBusinessDetails().then((value) {
      if (mounted) {
        setState(() {
          symbol = value['symbol'];
        });
      }
    });
  }

  onFilter() {
    if (mounted) {
      nextPage = url;
      if (selectedLocation['id'] != 0) {
        nextPage = nextPage! + "&location_id=${selectedLocation['id']}";
      }
      if (selectedCustomer['id'] != 0) {
        nextPage = nextPage! + "&contact_id=${selectedCustomer['id']}";
      }
      if (selectedPaymentStatus != 'all') {
        nextPage = nextPage! + "&payment_status=$selectedPaymentStatus";
      } else if (selectedPaymentStatus == 'all') {
        List<String> status = List.from(paymentStatuses);
        status.remove('all');
        String statuses = status.join(',');
        nextPage = nextPage! + "&payment_status=$statuses";
      }
      if (startDateRange != null && endDateRange != null) {
        nextPage =
            nextPage! + "&start_date=$startDateRange&end_date=$endDateRange";
      }
      changeUrl = true;
      setAllSalesList();
    }
  }

  void setAllSalesList() async {
    if (mounted) {
      setState(() {
        if (changeUrl) {
          allSalesListMap = [];
          changeUrl = false;
          showFilter = false;
        }
        isLoading = true;
      });
    }
    final dio = new Dio();
    var token = await System().getToken();
    dio.options.headers['content-Type'] = 'application/json';
    dio.options.headers["Authorization"] = "Bearer $token";
    final response = await dio.get(nextPage!);
    List sales = response.data['data'];
    Map links = response.data['links'];
    nextPage = links['next'];
    sales.forEach((sell) async {
      var paidAmount;
      List payments = sell['payment_lines'];
      double totalPaid = 0.00;
      Map<String, dynamic>? customer =
      await Contact().getCustomerDetailById(sell['contact_id']);
      var location = await Helper().getLocationNameById(sell['location_id']);
      payments.forEach((element) {
        totalPaid += double.parse(element['amount']);
      });
      (totalPaid <= double.parse(sell['final_total']))
          ? paidAmount = Helper().formatCurrency(totalPaid)
          : paidAmount = Helper().formatCurrency(sell['final_total']);

      allSalesListMap.add({
        'id': sell['id'],
        'location_name': location,
        'contact_name': customer != null ? customer['name'] : '',
        'mobile': customer != null ? customer['mobile'] : null,
        'invoice_no': sell['invoice_no'],
        'invoice_url': sell['invoice_url'],
        'date_time': sell['transaction_date'],
        'invoice_amount': sell['final_total'] != null
            ? double.parse(sell['final_total'].toString()).toStringAsFixed(2)
            : '0.00',
        'status': sell['payment_status'] ?? sell['status'],
        'paid_amount': paidAmount,
        'is_quotation': sell['is_quotation'].toString()
      });

      if (this.mounted) {
        setState(() {
          isLoading = false;
        });
      }
    });
  }

  String checkStatus(double invoiceAmount, double pendingAmount) {
    if (pendingAmount == invoiceAmount)
      return 'due';
    else if (pendingAmount >= 0.01)
      return 'partial';
    else
      return 'paid';
  }

  Color checkStatusColor(String? status) {
    if (status != null) {
      if (status.toLowerCase() == 'paid')
        return Colors.green;
      else if (status.toLowerCase() == 'due')
        return Colors.red;
      else
        return Colors.orange;
    } else {
      return Colors.black12;
    }
  }

  updateSellsFromApi() async {
    List transactionIds = await SellDatabase().getTransactionIds();

    if (transactionIds.isNotEmpty) {
      List specificSales = await SellApi().getSpecifiedSells(transactionIds);

      specificSales.forEach((element) async {
        List sell = await SellDatabase().getSellByTransactionId(element['id']);

        if (sell.length > 0) {
          await PaymentDatabase().delete(sell[0]['id']);
          element['payment_lines'].forEach((value) async {
            await PaymentDatabase().store({
              'sell_id': sell[0]['id'],
              'method': value['method'],
              'amount': value['amount'],
              'note': value['note'],
              'payment_id': value['id'],
              'is_return': value['is_return'],
              'account_id': value['account_id']
            });
          });

          await SellDatabase().deleteSellLineBySellId(sell[0]['id']);

          element['sell_lines'].forEach((value) async {
            await SellDatabase().store({
              'sell_id': sell[0]['id'],
              'product_id': value['product_id'],
              'variation_id': value['variation_id'],
              'quantity': value['quantity'],
              'unit_price': value['unit_price_before_discount'],
              'tax_rate_id': value['tax_id'],
              'discount_amount': value['line_discount_amount'],
              'discount_type': value['line_discount_type'],
              'note': value['sell_line_note'],
              'is_completed': 1
            });
          });
          updateSells(element);
        }
      });
    }
  }

  updateSells(sells) async {
    var changeReturn = 0.0;
    var pendingAmount = 0.0;
    var totalAmount = 0.0;
    List sell = await SellDatabase().getSellByTransactionId(sells['id']);
    await PaymentDatabase().get(sell[0]['id'], allColumns: true).then((value) {
      value.forEach((element) {
        if (element['is_return'] == 1) {
          changeReturn += element['amount'];
        } else {
          totalAmount += element['amount'];
        }
      });
    });
    if (double.parse(sells['final_total']) > totalAmount) {
      pendingAmount = double.parse(sells['final_total']) - totalAmount;
    }
    Map<String, dynamic> sellMap =
    Sell().createSellMap(sells, changeReturn, pendingAmount);
    await SellDatabase().updateSells(sell[0]['id'], sellMap);
  }

  String normalizeNumber(String amount) {
    String normalized = amount.replaceAll(',', '');
    double parsed = double.tryParse(normalized) ?? 0.0;
    return parsed.toStringAsFixed(2);
  }
}