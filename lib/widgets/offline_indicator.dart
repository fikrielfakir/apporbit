
import 'package:flutter/material.dart';
import '../models/offline_manager.dart';
import '../locale/MyLocalizations.dart';

class OfflineIndicator extends StatefulWidget {
  @override
  _OfflineIndicatorState createState() => _OfflineIndicatorState();
}

class _OfflineIndicatorState extends State<OfflineIndicator> {
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _checkOfflineStatus();
  }

  void _checkOfflineStatus() async {
    final isOffline = OfflineManager().isOfflineMode;
    if (mounted) {
      setState(() {
        _isOffline = isOffline;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isOffline) return SizedBox.shrink();
    
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.orange.shade100,
      child: Row(
        children: [
          Icon(Icons.cloud_off, color: Colors.orange.shade700, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              AppLocalizations.of(context).translate('offline_mode_active'),
              style: TextStyle(
                color: Colors.orange.shade700,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              await OfflineManager().setOfflineMode(false);
              _checkOfflineStatus();
            },
            child: Text(
              AppLocalizations.of(context).translate('go_online'),
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
}
