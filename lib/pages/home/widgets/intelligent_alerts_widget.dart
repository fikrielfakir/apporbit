
import 'package:flutter/material.dart';
import 'package:pos_final/services/intelligent_alerts_service.dart';

class IntelligentAlertsWidget extends StatefulWidget {
  final ThemeData themeData;

  const IntelligentAlertsWidget({
    Key? key,
    required this.themeData,
  }) : super(key: key);

  @override
  State<IntelligentAlertsWidget> createState() => _IntelligentAlertsWidgetState();
}

class _IntelligentAlertsWidgetState extends State<IntelligentAlertsWidget> {
  final IntelligentAlertsService _alertsService = IntelligentAlertsService();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    await _alertsService.checkAlerts();
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        margin: EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text('Loading alerts...'),
              ],
            ),
          ),
        ),
      );
    }

    final alerts = _alertsService.alerts;

    if (alerts.isEmpty) {
      return Container(
        margin: EdgeInsets.all(16),
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'All Good! 👍',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                      Text(
                        'No alerts at the moment',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      margin: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notifications_active,
                  color: widget.themeData.colorScheme.primary),
              SizedBox(width: 8),
              Text(
                'Smart Alerts',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              SizedBox(width: 8),
              if (alerts.length > 3)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '+${alerts.length - 3}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 12),
          ...alerts.take(3).map((alert) => _buildAlertCard(alert)),
          if (alerts.length > 3)
            TextButton(
              onPressed: _showAllAlerts,
              child: Text('View All Alerts (${alerts.length})'),
            ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(AlertItem alert) {
    Color cardColor;
    Color iconColor;

    switch (alert.type) {
      case AlertType.success:
        cardColor = Colors.green.shade50;
        iconColor = Colors.green;
        break;
      case AlertType.warning:
        cardColor = Colors.orange.shade50;
        iconColor = Colors.orange;
        break;
      case AlertType.error:
        cardColor = Colors.red.shade50;
        iconColor = Colors.red;
        break;
      case AlertType.info:
        cardColor = Colors.blue.shade50;
        iconColor = Colors.blue;
        break;
    }

    return Container(
      margin: EdgeInsets.only(bottom: 8),
      child: Card(
        elevation: 2,
        color: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(alert.icon, color: iconColor, size: 20),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alert.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      alert.message,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              if (alert.action != null)
                TextButton(
                  onPressed: () => _handleAlertAction(alert),
                  child: Text(
                    alert.action!,
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              IconButton(
                onPressed: () => _dismissAlert(alert.id),
                icon: Icon(Icons.close, size: 16),
                constraints: BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleAlertAction(AlertItem alert) {
    if (alert.route != null) {
      Navigator.pushNamed(context, alert.route!);
    } else if (alert.action == 'Sync Now') {
      _syncData();
    }
  }

  void _dismissAlert(String alertId) {
    setState(() {
      _alertsService.dismissAlert(alertId);
    });
  }

  void _syncData() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Syncing data...'),
        backgroundColor: widget.themeData.colorScheme.primary,
      ),
    );
  }

  void _showAllAlerts() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'All Alerts',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close),
                ),
              ],
            ),
            SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: _alertsService.alerts.map((alert) => _buildAlertCard(alert)).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
