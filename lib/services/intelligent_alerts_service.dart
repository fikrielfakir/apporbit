
import 'package:flutter/material.dart';
import 'package:pos_final/models/sellDatabase.dart';
import 'package:pos_final/models/offline_manager.dart';
import 'package:pos_final/models/system.dart';

class IntelligentAlertsService {
  static final IntelligentAlertsService _instance = IntelligentAlertsService._internal();
  factory IntelligentAlertsService() => _instance;
  IntelligentAlertsService._internal();

  List<AlertItem> _alerts = [];

  List<AlertItem> get alerts => _alerts;

  Future<void> checkAlerts() async {
    _alerts.clear();

    await _checkLowStockAlert();
    await _checkSalesGoalAlert();
    await _checkOfflineModeAlert();
    await _checkPendingPaymentsAlert();
    await _checkSyncAlert();
  }

  Future<void> _checkLowStockAlert() async {
    try {
      final products = await System().get('product');
      int lowStockCount = 0;

      for (var product in products) {
        if (product['enable_stock'] == 1) {
          double stockAvailable = double.tryParse(product['stock_available'].toString()) ?? 0;
          double minStock = double.tryParse(product['alert_quantity'].toString()) ?? 5;

          if (stockAvailable <= minStock && stockAvailable > 0) {
            lowStockCount++;
          }
        }
      }

      if (lowStockCount > 0) {
        _alerts.add(AlertItem(
          id: 'low_stock',
          title: 'Low Stock Alert',
          message: '$lowStockCount products are running low on stock',
          type: AlertType.warning,
          icon: Icons.warning,
          action: 'View Products',
          route: '/products',
          priority: AlertPriority.medium,
        ));
      }
    } catch (e) {
      print('Error checking low stock: $e');
    }
  }

  Future<void> _checkSalesGoalAlert() async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(Duration(days: 1));

      final sales = await SellDatabase().getSalesByDateRange(
        startOfDay.toIso8601String(),
        endOfDay.toIso8601String(),
      );

      double todaySales = 0.0;
      for (var sale in sales) {
        todaySales += (sale['invoice_amount'] ?? 0.0).toDouble();
      }

      // Assuming daily goal of $1000 (you can make this configurable)
      double dailyGoal = 1000.0;
      double percentage = (todaySales / dailyGoal) * 100;

      if (percentage >= 100) {
        _alerts.add(AlertItem(
          id: 'goal_achieved',
          title: '🎉 Goal Achieved!',
          message: 'Congratulations! You\'ve reached today\'s sales goal of \$${dailyGoal.toStringAsFixed(2)}',
          type: AlertType.success,
          icon: Icons.celebration,
          priority: AlertPriority.low,
        ));
      } else if (percentage >= 80) {
        _alerts.add(AlertItem(
          id: 'goal_almost',
          title: 'Almost There!',
          message: 'You\'re ${percentage.toStringAsFixed(1)}% towards your daily goal. Keep going!',
          type: AlertType.info,
          icon: Icons.trending_up,
          priority: AlertPriority.low,
        ));
      }
    } catch (e) {
      print('Error checking sales goal: $e');
    }
  }

  Future<void> _checkOfflineModeAlert() async {
    final offlineManager = OfflineManager();
    await offlineManager.initialize();

    if (offlineManager.isOfflineMode) {
      final cachedData = await offlineManager.getCachedDataSummary();
      int totalCachedItems = cachedData.values.fold(0, (sum, count) => sum + count);

      _alerts.add(AlertItem(
        id: 'offline_mode',
        title: 'Offline Mode Active',
        message: 'You\'re working offline with $totalCachedItems cached items. Sync when online.',
        type: AlertType.warning,
        icon: Icons.cloud_off,
        action: 'Sync Now',
        priority: AlertPriority.medium,
      ));
    }
  }

  Future<void> _checkPendingPaymentsAlert() async {
    try {
      final sales = await SellDatabase().getPendingPaymentSales();

      if (sales.isNotEmpty) {
        double totalPending = 0.0;
        for (var sale in sales) {
          totalPending += (sale['pending_amount'] ?? 0.0).toDouble();
        }

        if (totalPending > 0) {
          _alerts.add(AlertItem(
            id: 'pending_payments',
            title: 'Pending Payments',
            message: '${sales.length} sales with \$${totalPending.toStringAsFixed(2)} pending',
            type: AlertType.warning,
            icon: Icons.payment,
            action: 'View Sales',
            route: '/sale',
            priority: AlertPriority.high,
          ));
        }
      }
    } catch (e) {
      print('Error checking pending payments: $e');
    }
  }

  Future<void> _checkSyncAlert() async {
    try {
      final unsyncedSales = await SellDatabase().getNotSyncedSells();

      if (unsyncedSales.isNotEmpty) {
        _alerts.add(AlertItem(
          id: 'unsynced_data',
          title: 'Unsynced Data',
          message: '${unsyncedSales.length} sales need to be synced to server',
          type: AlertType.info,
          icon: Icons.sync_problem,
          action: 'Sync Now',
          priority: AlertPriority.medium,
        ));
      }
    } catch (e) {
      print('Error checking sync status: $e');
    }
  }

  void dismissAlert(String alertId) {
    _alerts.removeWhere((alert) => alert.id == alertId);
  }

  int get alertCount => _alerts.length;

  int get highPriorityAlertCount =>
      _alerts.where((alert) => alert.priority == AlertPriority.high).length;
}

class AlertItem {
  final String id;
  final String title;
  final String message;
  final AlertType type;
  final IconData icon;
  final String? action;
  final String? route;
  final AlertPriority priority;
  final DateTime timestamp;

  AlertItem({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.icon,
    this.action,
    this.route,
    required this.priority,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

enum AlertType {
  success,
  warning,
  error,
  info,
}

enum AlertPriority {
  high,
  medium,
  low,
}
