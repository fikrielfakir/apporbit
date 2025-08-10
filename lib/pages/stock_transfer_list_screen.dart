import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../api_end_points.dart';
import '../apis/api.dart';
import '../models/stock_transfer.dart';
import '../models/system.dart';
import 'create_stock_transfer_screen.dart';
import 'edit_stock_transfer_screen.dart';
import '../../../locale/MyLocalizations.dart';

// Custom Debouncer implementation
class Debouncer {
  final Duration delay;
  Timer? _timer;

  Debouncer({required this.delay});

  void call(void Function() callback) {
    _timer?.cancel();
    _timer = Timer(delay, callback);
  }

  void dispose() {
    _timer?.cancel();
  }
}

class StockTransferListScreen extends StatefulWidget {
  const StockTransferListScreen({Key? key}) : super(key: key);

  @override
  _StockTransferListScreenState createState() => _StockTransferListScreenState();
}

class _StockTransferListScreenState extends State<StockTransferListScreen> {
  final Api _api = Api();
  List<StockTransfer> _transfers = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _currentPage = 1;
  final int _perPage = 20;
  bool _hasMorePages = true;
  int? _selectedLocationId;
  int? _currentLocationId;
  String? _selectedStatus;
  DateTimeRange? _dateRange;
  final ScrollController _scrollController = ScrollController();
  final _searchController = TextEditingController();
  bool _isDisposed = false;

  // For debouncing search
  final Debouncer _searchDebouncer = Debouncer(delay: Duration(milliseconds: 500));

  // To show and hide the floating app bar
  bool _showAppBarTitle = false;

  @override
  void initState() {
    super.initState();
    _isDisposed = false;
    _getCurrentLocation().then((_) => _loadTransfers());
    _scrollController.addListener(_scrollListener);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _isDisposed = true;
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _searchController.dispose();
    _searchDebouncer.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _searchDebouncer.call(() {
      if (!_isDisposed) {
        _loadTransfers();
      }
    });
  }

  void _scrollListener() {
    // For infinite scrolling
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMorePages && !_isDisposed) {
        _loadMoreTransfers();
      }
    }

    // For app bar title visibility
    setState(() {
      _showAppBarTitle = _scrollController.position.pixels > 120;
    });
  }

  Future<void> _getCurrentLocation() async {
    try {
      final currentLocation = await System().getCurrentLocation();
      if (currentLocation != null && !_isDisposed) {
        setState(() {
          _currentLocationId = currentLocation['id'];
          _selectedLocationId = _currentLocationId;
        });
      }
    } catch (e) {
      debugPrint('Error getting current location: ${e.toString()}');
    }
  }

  Future<void> _loadTransfers({bool reset = true}) async {
    if (_isDisposed) return;

    if (!_isDisposed) {
      setState(() {
        _isLoading = reset ? true : _isLoading;
        if (reset) {
          _currentPage = 1;
          _hasMorePages = true;
        }
      });
    }

    try {
      final token = await System().getToken();
      final currentLocation = await System().getCurrentLocation();
      final currentLocationId = currentLocation?['id'];
      final currentUser = await System().getCurrentUserId();
      print('Current User ID: $currentUser'); // Debug log

      final response = await _api.authenticatedRequest(
        endpoint: _buildApiEndpoint(currentLocationId),
        method: 'GET',
        token: token,
      );

      if (_isDisposed) return;

      if (response['success'] == true) {
        final data = response['data'];
        final meta = data['meta'] ?? {};

        final transfers = (data['data'] as List)
            .map((t) => StockTransfer.fromJson(t))
            .where((transfer) =>
        (transfer.locationId == currentLocationId ||
            transfer.transferLocationId == currentLocationId) &&
            transfer.demandeurId > 0 &&
            transfer.demandeurId == currentUser
        )
            .toList();

        if (!_isDisposed) {
          setState(() {
            _transfers = reset ? transfers : [..._transfers, ...transfers];
            _hasMorePages = (meta['current_page'] ?? 1) < (meta['last_page'] ?? 1);
            _isLoading = false;
          });
        }
      } else {
        throw Exception(response['error'] ?? 'Failed to load transfers');
      }
    } catch (e) {
      if (_isDisposed) return;
      debugPrint('Error loading transfers: ${e.toString()}');
      // Remove the stackTrace line if you don't need it
      if (mounted) {
       print('Error loading transfers: ${e.toString()}');
      }
      if (!_isDisposed) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _buildApiEndpoint(int? currentLocationId) {
    return '${ApiEndPoints.stockTransfers}?page=$_currentPage'
        '&per_page=$_perPage'
        '${currentLocationId != null ? '&current_location_id=$currentLocationId' : ''}'
        '${_selectedStatus != null ? '&status=$_selectedStatus' : ''}'
        '${_dateRange != null ? '&start_date=${DateFormat('yyyy-MM-dd').format(_dateRange!.start)}' : ''}'
        '${_dateRange != null ? '&end_date=${DateFormat('yyyy-MM-dd').format(_dateRange!.end)}' : ''}'
        '${_searchController.text.isNotEmpty ? '&search_term=${Uri.encodeComponent(_searchController.text)}' : ''}'
        '&include=location_from,location_to,purchase_transfer';
  }

  Future<void> _loadMoreTransfers() async {
    if (_isLoadingMore || !_hasMorePages || _isDisposed) return;

    if (!_isDisposed) {
      setState(() => _isLoadingMore = true);
    }
    _currentPage++;

    try {
      await _loadTransfers(reset: false);
    } catch (e) {
      if (_isDisposed) return;
      debugPrint('Error: ${e.toString()}');
      if (mounted) {
        _showErrorSnackBar(AppLocalizations.of(context).translate('error_loading_more'));
      }
    } finally {
      if (!_isDisposed) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        backgroundColor: Colors.red.shade600,
        duration: Duration(seconds: 3),
        action: SnackBarAction(
          label: AppLocalizations.of(context).translate('retry'),
          textColor: Colors.white,
          onPressed: _loadTransfers,
        ),
      ),
    );
  }

  Widget _buildTransferCard(StockTransfer transfer, int index) {
    final isFinalStatus = transfer.status.toLowerCase() == 'final';
    final backgroundColor = isFinalStatus
        ? Colors.green.shade50
        : transfer.status.toLowerCase() == 'in_transit'
        ? Colors.orange.shade100
        : Colors.red.shade50;

    return Hero(
      tag: 'transfer_${transfer.id}',
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200 + (index * 30)),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 2,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          borderRadius: BorderRadius.circular(12),
          color: backgroundColor,
          child: isFinalStatus
              ? Padding(
            padding: const EdgeInsets.all(16),
            child: _buildTransferContent(transfer),
          )
              : InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _navigateToEditScreen(transfer),
            splashColor: Theme.of(context).primaryColor.withOpacity(0.1),
            highlightColor: Theme.of(context).primaryColor.withOpacity(0.05),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildTransferContent(transfer),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTransferContent(StockTransfer transfer) {
    final isFromCurrentLocation = transfer.locationId == (_currentLocationId ?? 0);
    final isToCurrentLocation = transfer.transferLocationId == (_currentLocationId ?? 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                transfer.refNo,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _buildStatusBadge(transfer.status),
          ],
        ),
        const SizedBox(height: 12),
        _buildLocationRow(
          icon: isToCurrentLocation ?  Icons.warehouse :Icons.local_shipping,
          label: AppLocalizations.of(context).translate('from'),
          locationId: transfer.locationId,
          locationName: transfer.locationName,
          currentLocationId: _currentLocationId ?? 0,
        ),
        const SizedBox(height: 8),
        _buildLocationRow(
          icon: isToCurrentLocation ? Icons.local_shipping : Icons.warehouse,
          label: AppLocalizations.of(context).translate('to'),
          locationId: transfer.transferLocationId,
          locationName: transfer.transferLocationName,
          currentLocationId: _currentLocationId ?? 0,
        ),
        const SizedBox(height: 12),
        _buildInfoRow(transfer),
        if (transfer.additionalNotes != null &&
            transfer.additionalNotes!.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildNotesContainer(transfer.additionalNotes!),
        ],
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: _getStatusColor(status).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _getStatusColor(status),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _getStatusIcon(status),
          const SizedBox(width: 4),
          Text(
            _getLocalizedStatus(status),
            style: TextStyle(
              color: _getStatusColor(status),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'final':
        return Icon(Icons.check_circle_outline, size: 14, color: Colors.green.shade600);
      case 'in_transit':
        return Icon(Icons.local_shipping_outlined, size: 14, color: Colors.orange.shade600);
      case 'pending':
        return Icon(Icons.pending_outlined, size: 14, color: Colors.red.shade700);
      default:
        return Icon(Icons.circle, size: 14, color: Colors.grey.shade600);
    }
  }

  Widget _buildLocationRow({
    required IconData icon,
    required String label,
    required int locationId,
    required String locationName,
    required int currentLocationId,
  }) {
    final isCurrentLocation = locationId == currentLocationId;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isCurrentLocation ? Colors.blue.shade100 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCurrentLocation ? Colors.grey.shade100 : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
              icon,
              size:43,
              color: isCurrentLocation ? Colors.green : Theme.of(context).primaryColor
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  locationName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isCurrentLocation ? Colors.blue.shade800 : null,
                  ),
                ),

              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(StockTransfer transfer) {
    return Row(
      children: [
        _buildInfoItem(
          icon: Icons.calendar_today,
          text: transfer.formattedDate,
        ),
        const SizedBox(width: 16),
        _buildInfoItem(
          icon: Icons.access_time,
          text: transfer.formattedTime,
        ),
      ],
    );
  }

  Widget _buildInfoItem({required IconData icon, required String text}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildNotesContainer(String notes) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.note, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              notes,
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: Colors.grey.shade700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getLocalizedStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return AppLocalizations.of(context).translate('pending');
      case 'in_transit':
        return AppLocalizations.of(context).translate('in_transit');
      case 'final':
        return AppLocalizations.of(context).translate('finals');
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'final':
        return Colors.green.shade600;
      case 'in_transit':
        return Colors.orange.shade600;
      case 'pending':
        return Colors.red.shade700;
      default:
        return Colors.grey.shade600;
    }
  }

  Widget _buildSearchField() {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        elevation: 0,
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context).translate('search_transfers'),
            prefixIcon: Icon(Icons.search, color: Theme.of(context).primaryColor.withOpacity(0.7)),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
              icon: Icon(Icons.clear, color: Colors.grey.shade600),
              onPressed: () {
                _searchController.clear();
                // Will trigger via listener
              },
            )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Theme.of(context).primaryColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    final hasFilters = _selectedLocationId != _currentLocationId ||
        _selectedStatus != null ||
        _dateRange != null;

    if (!hasFilters) return SizedBox(height: 8);

    return Container(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16),
        children: [
          if (_selectedLocationId != null && _selectedLocationId != _currentLocationId)
            _buildFilterChip(
              label: '${AppLocalizations.of(context).translate('location')}: ${_selectedLocationId}',
              onDeleted: () {
                setState(() => _selectedLocationId = _currentLocationId);
                _loadTransfers();
              },
            ),
          if (_selectedStatus != null)
            _buildFilterChip(
              label: '${AppLocalizations.of(context).translate('status')}: ${_getLocalizedStatus(_selectedStatus!)}',
              onDeleted: () {
                setState(() => _selectedStatus = null);
                _loadTransfers();
              },
            ),
          if (_dateRange != null)
            _buildFilterChip(
              label:
              '${DateFormat('MMM d').format(_dateRange!.start)} - ${DateFormat('MMM d').format(_dateRange!.end)}',
              onDeleted: () {
                setState(() => _dateRange = null);
                _loadTransfers();
              },
            ),
          // Clear all filters chip
          if (hasFilters)
            Container(
              margin: EdgeInsets.only(right: 8),
              child: ActionChip(
                label: Text(
                  AppLocalizations.of(context).translate('clear_all'),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                avatar: Icon(
                  Icons.clear_all,
                  size: 18,
                  color: Theme.of(context).colorScheme.error,
                ),
                backgroundColor: Theme.of(context).colorScheme.error.withOpacity(0.1),
                onPressed: () {
                  setState(() {
                    _selectedLocationId = _currentLocationId;
                    _selectedStatus = null;
                    _dateRange = null;
                  });
                  _loadTransfers();
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({required String label, required VoidCallback onDeleted}) {
    return Container(
      margin: EdgeInsets.only(right: 8),
      child: Chip(
        label: Text(
          label,
          style: TextStyle(
            color: Theme.of(context).primaryColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        deleteIcon: Icon(Icons.close, size: 16),
        onDeleted: onDeleted,
        backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: Theme.of(context).primaryColor.withOpacity(0.2),
          ),
        ),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        labelPadding: EdgeInsets.symmetric(horizontal: 4),
        padding: EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }

  Future<void> _navigateToEditScreen(StockTransfer transfer) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditStockTransferScreen(
          transferId: transfer.id,
          locationId: transfer.locationId,
          transferLocationId: transfer.transferLocationId,
        ),
      ),
    );

    if (result == true && mounted) {
      _loadTransfers();
    }
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final initialDateRange = _dateRange ??
        DateTimeRange(
          start: DateTime.now().subtract(Duration(days: 30)),
          end: DateTime.now(),
        );

    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: initialDateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() => _dateRange = picked);
      _loadTransfers();
    }
  }

  void _showStatusFilter() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context).translate('select_status'),
                style: Theme.of(context).textTheme.headline6,
              ),
              const SizedBox(height: 16),
              Column(
                children: [
                  _buildStatusOption(
                    title: AppLocalizations.of(context).translate('all_statuses'),
                    icon: Icons.all_inclusive,
                    iconColor: Colors.grey.shade600,
                    isSelected: _selectedStatus == null,
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _selectedStatus = null);
                      _loadTransfers();
                    },
                  ),
                  _buildStatusOption(
                    title: AppLocalizations.of(context).translate('pending'),
                    icon: Icons.pending,
                    iconColor: Colors.red.shade700,
                    isSelected: _selectedStatus == 'pending',
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _selectedStatus = 'pending');
                      _loadTransfers();
                    },
                  ),
                  _buildStatusOption(
                    title: AppLocalizations.of(context).translate('in_transit'),
                    icon: Icons.local_shipping,
                    iconColor: Colors.orange.shade600,
                    isSelected: _selectedStatus == 'in_transit',
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _selectedStatus = 'in_transit');
                      _loadTransfers();
                    },
                  ),
                  _buildStatusOption(
                    title: AppLocalizations.of(context).translate('completed'),
                    icon: Icons.check_circle,
                    iconColor: Colors.green.shade600,
                    isSelected: _selectedStatus == 'completed',
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _selectedStatus = 'completed');
                      _loadTransfers();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusOption({
    required String title,
    required IconData icon,
    required Color iconColor,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return ListTile(
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      leading: Icon(icon, color: iconColor),
      trailing: isSelected ? Icon(Icons.check, color: Theme.of(context).primaryColor) : null,
      onTap: onTap,
      tileColor: isSelected ? Theme.of(context).primaryColor.withOpacity(0.05) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  void _showFilterBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          builder: (BuildContext context, ScrollController scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: SingleChildScrollView(
                controller: scrollController,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        AppLocalizations.of(context).translate('filter_transfers'),
                        style: Theme.of(context).textTheme.headline6,
                      ),
                      const SizedBox(height: 16),
                      _buildFilterOption(
                        icon: Icons.location_on,
                        title: AppLocalizations.of(context).translate('location'),
                        value: _selectedLocationId != null
                            ? 'ID: $_selectedLocationId'
                            : AppLocalizations.of(context).translate('all_locations'),
                        onTap: () {
                          Navigator.pop(context);
                          _showLocationFilter();
                        },
                      ),
                      _buildFilterOption(
                        icon: Icons.inventory,
                        title: AppLocalizations.of(context).translate('status'),
                        value: _selectedStatus != null
                            ? _getLocalizedStatus(_selectedStatus!)
                            : AppLocalizations.of(context).translate('all_statuses'),
                        onTap: () {
                          Navigator.pop(context);
                          _showStatusFilter();
                        },
                      ),
                      _buildFilterOption(
                        icon: Icons.calendar_today,
                        title: AppLocalizations.of(context).translate('date_range'),
                        value: _dateRange != null
                            ? '${DateFormat('MMM d, yyyy').format(_dateRange!.start)} - '
                            '${DateFormat('MMM d, yyyy').format(_dateRange!.end)}'
                            : AppLocalizations.of(context).translate('all_dates'),
                        onTap: () {
                          Navigator.pop(context);
                          _selectDateRange(context);
                        },
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: Icon(Icons.refresh),
                              label: Text(AppLocalizations.of(context).translate('reset_filters')),
                              onPressed: () {
                                Navigator.pop(context);
                                setState(() {
                                  _selectedLocationId = _currentLocationId;
                                  _selectedStatus = null;
                                  _dateRange = null;
                                });
                                _loadTransfers();
                              },
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: Icon(Icons.filter_alt),
                              label: Text(AppLocalizations.of(context).translate('apply_filters')),
                              onPressed: () {
                                Navigator.pop(context);
                                _loadTransfers();
                              },
                              style: ElevatedButton.styleFrom(
                                primary: Theme.of(context).primaryColor,
                                padding: EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterOption({
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Theme.of(context).primaryColor, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade500),
          ],
        ),
      ),
    );
  }

  Future<void> _showLocationFilter() async {
    try {
      final locations = await System().get('location');

      if (!mounted) return;

      final allLocationOption = {
        'id': 0,
        'name': AppLocalizations.of(context).translate('all_locations')
      };
      final locationOptions = [allLocationOption, ...locations];

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (BuildContext context) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        AppLocalizations.of(context).translate('select_location'),
                        style: Theme.of(context).textTheme.headline6,
                      ),
                      const SizedBox(height: 8),
                      // Search locations
                      TextField(
                        decoration: InputDecoration(
                          hintText: AppLocalizations.of(context).translate('search_locations'),
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          contentPadding: EdgeInsets.symmetric(vertical: 0),
                        ),
                        onChanged: (value) {
                          // You could implement local filtering of locations here
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    itemCount: locationOptions.length,
                    itemBuilder: (context, index) {
                      final location = locationOptions[index];
                      final isSelected = _selectedLocationId == location['id'] ||
                          (location['id'] == 0 && _selectedLocationId == null);

                      return Card(
                        margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        elevation: 0,
                        color: isSelected
                            ? Theme.of(context).primaryColor.withOpacity(0.1)
                            : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: isSelected
                                ? Theme.of(context).primaryColor
                                : Colors.grey.shade200,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () {
                            Navigator.pop(context);
                            setState(() {
                              _selectedLocationId = location['id'] == 0 ? null : location['id'];
                            });
                            _loadTransfers();
                          },
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Theme.of(context).primaryColor
                                        : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    location['id'] == 0 ? Icons.all_inclusive : Icons.location_on,
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.grey.shade600,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        location['name'] ?? AppLocalizations.of(context).translate('unknown_location'),
                                        style: TextStyle(
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                          fontSize: 16,
                                          color: isSelected ? Theme.of(context).primaryColor : null,
                                        ),
                                      ),
                                      if (location['id'] != 0)
                                        Text(
                                          'ID: ${location['id']}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  Icon(Icons.check_circle, color: Theme.of(context).primaryColor),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    } catch (e) {
      debugPrint('Error fetching locations: ${e.toString()}');
      if (!mounted) return;
      _showErrorSnackBar(AppLocalizations.of(context).translate('error_fetching_locations'));
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.inventory_2_outlined,
              size: 70,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            AppLocalizations.of(context).translate('no_transfers_found'),
            style: Theme.of(context).textTheme.headline6?.copyWith(
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              _searchController.text.isNotEmpty
                  ? AppLocalizations.of(context).translate('try_different_search')
                  : AppLocalizations.of(context).translate('no_transfers_description'),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          const SizedBox(height: 24),
          if (_selectedLocationId != _currentLocationId ||
              _selectedStatus != null ||
              _dateRange != null ||
              _searchController.text.isNotEmpty)
            ElevatedButton.icon(
              icon: Icon(Icons.refresh),
              label: Text(AppLocalizations.of(context).translate('clear_all_filters')),
              onPressed: () {
                setState(() {
                  _selectedLocationId = _currentLocationId;
                  _selectedStatus = null;
                  _dateRange = null;
                  _searchController.clear();
                });
                _loadTransfers();
              },
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),

        ],
      ),
    );
  }

  Widget _buildLoadMoreIndicator() {
    if (_isLoadingMore) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              AppLocalizations.of(context).translate('loading_more'),
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    } else if (_hasMorePages) {
      return TextButton.icon(
        icon: Icon(Icons.refresh),
        label: Text(AppLocalizations.of(context).translate('load_more')),
        onPressed: _loadMoreTransfers,
      );
    } else {
      return SizedBox(height: 16);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: AnimatedOpacity(
          opacity: _showAppBarTitle ? 1.0 : 0.0,
          duration: Duration(milliseconds: 250),
          child: Text(AppLocalizations.of(context).translate('stock_transfers')),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.white,
        iconTheme: IconThemeData(color: Theme.of(context).primaryColor),
        titleTextStyle: TextStyle(
          color: Colors.black87,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list_rounded),
            tooltip: AppLocalizations.of(context).translate('filters'),
            onPressed: () => _showFilterBottomSheet(context),
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            tooltip: AppLocalizations.of(context).translate('refresh'),
            onPressed: _loadTransfers,
          ),
        ],
      ),
      body: Column(
        children: [
          // Large title when scrolled to top
          AnimatedContainer(
            duration: Duration(milliseconds: 300),
            height: _showAppBarTitle ? 0 : 60,
            padding: EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.centerLeft,
            child: Text(
              AppLocalizations.of(context).translate('stock_transfers'),
              style: Theme.of(context).textTheme.headline5?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _buildSearchField(),
          _buildFilterChips(),
          Expanded(
            child: _isLoading
                ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
              ),
            )
                : _transfers.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
              color: Theme.of(context).primaryColor,
              onRefresh: _loadTransfers,
              child: ListView.builder(
                controller: _scrollController,
                physics: AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.only(bottom: 80),
                itemCount: _transfers.length + 1, // +1 for the load more indicator
                itemBuilder: (context, index) {
                  if (index == _transfers.length) {
                    return _buildLoadMoreIndicator();
                  }
                  return _buildTransferCard(_transfers[index], index);
                },
              ),
            ),
          ),
        ],
      ),

    );
  }
}