import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../apis/sell.dart';
import '../helpers/otherHelpers.dart';
import '../models/contact_model.dart';
import 'SellReturnDetailsScreen.dart';
import '../widgets/custom_error_widget.dart';

class SellReturnListScreen extends StatefulWidget {
  const SellReturnListScreen({Key? key}) : super(key: key);

  @override
  _SellReturnListScreenState createState() => _SellReturnListScreenState();
}

class _SellReturnListScreenState extends State<SellReturnListScreen> {
  List<Map<String, dynamic>> sellReturns = [];
  bool isLoading = true;
  String errorMessage = '';
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> filteredReturns = [];
  String _sortBy = 'date'; // Default sort by date
  bool _sortAscending = false; // Default sort descending (newest first)

  @override
  void initState() {
    super.initState();
    fetchSellReturns();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Fetches sell returns from the API
  Future<void> fetchSellReturns() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      var api = SellApi();
      var returns = await api.fetchSellReturns();

      // Fetch contact names for each return
      for (var sellReturn in returns) {
        var contactDetails = await Contact().getCustomerDetailById(sellReturn['contact_id']);
        sellReturn['contact_name'] = contactDetails['name']; // Add contact name to the sell return
      }

      setState(() {
        sellReturns = returns;
        _applySortAndFilter();
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Failed to fetch sell returns: $e';
      });
      _showErrorSnackBar(errorMessage);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: fetchSellReturns,
        ),
      ),
    );
  }

  void _applySortAndFilter() {
    // First apply search filter
    filteredReturns = _searchController.text.isEmpty
        ? List.from(sellReturns)
        : sellReturns
        .where((sellReturn) =>
    sellReturn['invoice_no'].toString().toLowerCase().contains(_searchController.text.toLowerCase()) ||
        (sellReturn['contact_name'] != null &&
            sellReturn['contact_name'].toString().toLowerCase().contains(_searchController.text.toLowerCase())))
        .toList();

    // Then apply sorting
    filteredReturns.sort((a, b) {
      if (_sortBy == 'date') {
        return _sortAscending
            ? a['transaction_date'].compareTo(b['transaction_date'])
            : b['transaction_date'].compareTo(a['transaction_date']);
      } else if (_sortBy == 'amount') {
        return _sortAscending
            ? (double.parse(a['final_total'])).compareTo(double.parse(b['final_total']))
            : (double.parse(b['final_total'])).compareTo(double.parse(a['final_total']));
      } else {
        return _sortAscending
            ? a['invoice_no'].compareTo(b['invoice_no'])
            : b['invoice_no'].compareTo(a['invoice_no']);
      }
    });
  }

  /// Show the filter and sort options dialog
  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              const Text(
              'Sort Options',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            RadioListTile<String>(
              title: const Text('Sort by Date'),
              value: 'date',
              groupValue: _sortBy,
              onChanged: (value) {
                setModalState(() => _sortBy = value!);
              },
            ),
            RadioListTile<String>(
              title: const Text('Sort by Invoice Number'),
              value: 'invoice',
              groupValue: _sortBy,
              onChanged: (value) {
                setModalState(() => _sortBy = value!);
              },
            ),
            RadioListTile<String>(
              title: const Text('Sort by Amount'),
              value: 'amount',
              groupValue: _sortBy,
              onChanged: (value) {
                setModalState(() => _sortBy = value!);
              },
            ),
            CheckboxListTile(
              title: const Text('Ascending Order'),
              value: _sortAscending,
              onChanged: (value) {
                setModalState(() => _sortAscending = value!);
              },
            ),
            const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  onPressed: () {
                    setState(() {
                      _applySortAndFilter();
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('Apply'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final DateTime date = DateTime.parse(dateString);
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sell Returns'),
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
            tooltip: 'Sort Options',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchSellReturns,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading sell returns...'),
          ],
        ),
      );
    }

    if (errorMessage.isNotEmpty) {
      return CustomErrorWidget(
        message: errorMessage,
        onRetry: fetchSellReturns,
      );
    }

    return Column(
      children: [
        _buildSearchBar(),
        Expanded(
          child: sellReturns.isEmpty
              ? _buildEmptyState()
              : _buildReturnsList(),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search by invoice number or customer',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              setState(() {
                _searchController.clear();
                _applySortAndFilter();
              });
            },
          )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          filled: true,
          fillColor: Colors.grey[100],
        ),
        onChanged: (value) {
          setState(() {
            _applySortAndFilter();
          });
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.assignment_return,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          const Text(
            'No sell returns found',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _searchController.text.isNotEmpty
                ? 'Try adjusting your search criteria'
                : 'Returns will appear here when they are added',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: fetchSellReturns,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  Widget _buildReturnsList() {
    return RefreshIndicator(
      onRefresh: fetchSellReturns,
      child: ListView.builder(
        itemCount: filteredReturns.length,
        padding: const EdgeInsets.only(bottom: 16),
        itemBuilder: (context, index) {
          final sellReturn = filteredReturns[index];
          final String paymentStatus = sellReturn['payment_status'] ?? 'unknown';
          final String status = sellReturn['status'] ?? 'unknown';

          // Get the original transaction data if available
          final originalTransaction = sellReturn['return_parent_sell'];
          final hasOriginalData = originalTransaction != null;

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: Colors.grey.shade200,
                width: 1,
              ),
            ),
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SellReturnDetailScreen(
                      sellReturn: sellReturn, // Ensure this contains the product name
                    ),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Invoice: ${sellReturn['invoice_no']}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        _buildStatusChip(paymentStatus),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.person_outline, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            sellReturn['contact_name'] ?? 'Unknown Customer',
                            style: TextStyle(color: Colors.grey[800]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(sellReturn['transaction_date']),
                          style: TextStyle(color: Colors.grey[800]),
                        ),
                      ],
                    ),

                    // Add original invoice information if available
                    if (hasOriginalData) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.receipt_long, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            'Original Invoice: ${originalTransaction['invoice_no']}',
                            style: TextStyle(color: Colors.grey[800]),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Return Amount',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              Helper().formatCurrency(double.parse(sellReturn['final_total'])),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SellReturnDetailScreen(
                                  sellReturn: sellReturn, // Ensure this contains the product name
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            textStyle: const TextStyle(fontSize: 14),
                          ),
                          child: const Text('View Details'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color chipColor;
    String displayText;

    switch (status.toLowerCase()) {
      case 'paid':
        chipColor = Colors.green;
        displayText = 'Paid';
        break;
      case 'partial':
        chipColor = Colors.orange;
        displayText = 'Partial';
        break;
      case 'due':
        chipColor = Colors.red;
        displayText = 'Due';
        break;
      default:
        chipColor = Colors.grey;
        displayText = status.capitalizeFirst();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: chipColor.withOpacity(0.5)),
      ),
      child: Text(
        displayText,
        style: TextStyle(
          color: chipColor,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}

// Extension to capitalize first letter
extension StringExtension on String {
  String capitalizeFirst() {
    if (this.isEmpty) return this;
    return "${this[0].toUpperCase()}${this.substring(1)}";
  }
}