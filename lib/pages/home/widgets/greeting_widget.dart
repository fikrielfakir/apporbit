import 'dart:async';

import 'package:flutter/material.dart';
import '../../../locale/MyLocalizations.dart';

class GreetingWidget extends StatefulWidget implements PreferredSizeWidget {
  const GreetingWidget({
    Key? key,
    required this.themeData,
    required this.userName,
    this.onProfileTap,
  }) : super(key: key);

  final ThemeData themeData;
  final String userName;
  final VoidCallback? onProfileTap;
  static const double _kHeight = 100.0; // Increased height to accommodate date/time

  @override
  State<GreetingWidget> createState() => _GreetingWidgetState();

  @override
  Size get preferredSize => const Size.fromHeight(_kHeight);
}

class _GreetingWidgetState extends State<GreetingWidget> {
  late DateTime _currentTime;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _currentTime = DateTime.now();
    // Update time every minute
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      setState(() {
        _currentTime = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _getGreeting() {
    final hour = _currentTime.hour;

    if (hour < 5) {
      return AppLocalizations.of(context).translate('good_evening');
    } else if (hour < 12) {
      return AppLocalizations.of(context).translate('good_morning');
    } else if (hour < 17) {
      return AppLocalizations.of(context).translate('good_afternoon');
    } else {
      return AppLocalizations.of(context).translate('good_evening');
    }
  }

  IconData _getTimeBasedIcon() {
    final hour = _currentTime.hour;
    if (hour < 5) {
      return Icons.nightlight_round;
    } else if (hour < 12) {
      return Icons.wb_sunny;
    } else if (hour < 17) {
      return Icons.wb_cloudy;
    } else {
      return Icons.brightness_3;
    }
  }

  Color _getTimeBasedIconColor() {
    final hour = _currentTime.hour;
    if (hour < 5) {
      return Colors.blueGrey[200]!;
    } else if (hour < 12) {
      return Colors.amber[600]!;
    } else if (hour < 17) {
      return Colors.blueGrey[400]!;
    } else {
      return Colors.indigo[200]!;
    }
  }

  String _getFormattedDate() {
    return '${_currentTime.day}/${_currentTime.month}/${_currentTime.year}';
  }

  String _getFormattedTime() {
    final hour = _currentTime.hour;
    final minute = _currentTime.minute;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(20),
        shadowColor: widget.themeData.colorScheme.primary.withOpacity(0.8),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: widget.onProfileTap,
          highlightColor: Colors.white.withOpacity(0.2),
          splashColor: Colors.white.withOpacity(0.3),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  widget.themeData.colorScheme.primary.withOpacity(0.8),
                  widget.themeData.colorScheme.primary.withOpacity(0.7),
                  widget.themeData.colorScheme.secondary.withOpacity(0.8),
                ],
                stops: const [0.1, 0.6, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.themeData.colorScheme.primary.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // Avatar
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.8),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: widget.themeData.colorScheme.primary,
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.white,
                    child: Text(
                      widget.userName.isNotEmpty
                          ? widget.userName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: widget.themeData.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Greeting text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _getGreeting(),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.userName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getFormattedDate(),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                // Time and icon column
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _getFormattedTime(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Icon(
                      _getTimeBasedIcon(),
                      size: 24,
                      color: _getTimeBasedIconColor(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}