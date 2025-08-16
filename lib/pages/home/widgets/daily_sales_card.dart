
import 'package:flutter/material.dart';
import 'package:pos_final/models/sellDatabase.dart';
import 'package:pos_final/models/offline_manager.dart';

class DailySalesCard extends StatefulWidget {
  final ThemeData themeData;

  const DailySalesCard({
    Key? key,
    required this.themeData,
  }) : super(key: key);

  @override
  State<DailySalesCard> createState() => _DailySalesCardState();
}

class _DailySalesCardState extends State<DailySalesCard> {
  int _dailySalesCount = 0;
  double _dailySalesAmount = 0.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDailySales();
  }

  Future<void> _loadDailySales() async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(Duration(days: 1));

      // Try to get from local database first
      final sales = await SellDatabase().getSalesByDateRange(
        startOfDay.toIso8601String(),
        endOfDay.toIso8601String(),
      );

      double totalAmount = 0.0;
      int count = sales.length;

      for (var sale in sales) {
        totalAmount += (sale['invoice_amount'] ?? 0.0).toDouble();
      }

      // If no local data, try cached data
      if (count == 0) {
        final offlineManager = OfflineManager();
        final cachedSales = await offlineManager.getCachedSales();

        for (var sale in cachedSales) {
          final saleDate = DateTime.tryParse(sale['transaction_date'] ?? '');
          if (saleDate != null &&
              saleDate.isAfter(startOfDay) &&
              saleDate.isBefore(endOfDay)) {
            count++;
            totalAmount += (sale['invoice_amount'] ?? 0.0).toDouble();
          }
        }
      }

      if (mounted) {
        setState(() {
          _dailySalesCount = count;
          _dailySalesAmount = totalAmount;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading daily sales: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shadowColor: Colors.green.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.green.shade50,
              Colors.green.shade100,
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.today,
                    color: Colors.green.shade700,
                    size: 24,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Today\'s Sales',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800,
                        ),
                      ),
                      Text(
                        _formatDate(DateTime.now()),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isLoading)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Sales Count',
                    _dailySalesCount.toString(),
                    Icons.shopping_cart,
                    Colors.blue,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: _buildStatItem(
                    'Total Amount',
                    '\$${_dailySalesAmount.toStringAsFixed(2)}',
                    Icons.attach_money,
                    Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];

    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
