import 'package:flutter/material.dart';
import 'package:pos_final/helpers/AppTheme.dart';
import 'package:pos_final/helpers/SizeConfig.dart';
import 'package:pos_final/locale/MyLocalizations.dart';

class GreetingWidget extends StatefulWidget implements PreferredSizeWidget {
  const GreetingWidget({
    Key? key,
    required this.themeData,
    required this.userName,
  }) : super(key: key);

  final ThemeData themeData;
  final String userName;
  static const double _kTabHeight = 56.0; // Slightly increased height

  @override
  State<GreetingWidget> createState() => _GreetingWidgetState();

  @override
  Size get preferredSize => const Size.fromHeight(_kTabHeight);
}

class _GreetingWidgetState extends State<GreetingWidget>
    with SingleTickerProviderStateMixin {
  // Initialize controllers and animations in initState, not as late fields
  AnimationController? _controller;
  Animation<Offset>? _offsetAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize the animation controller
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Initialize the slide animation
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller!,
      curve: Curves.easeOutBack,
    ));

    // Start the animation
    _controller!.forward();
  }

  @override
  void dispose() {
    // Clean up resources
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Check if animations are properly initialized
    if (_controller == null || _offsetAnimation == null) {
      return const SizedBox.shrink(); // Return empty widget if animations aren't ready
    }

    return SlideTransition(
      position: _offsetAnimation!,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Container(
          alignment: Alignment.center,
          padding: EdgeInsets.all(MySize.size10!),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                widget.themeData.colorScheme.primary.withOpacity(0.7),
                widget.themeData.colorScheme.secondary.withOpacity(0.5),
              ],
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Add a small avatar or icon
              CircleAvatar(
                radius: MySize.size16,
                backgroundColor: Colors.white,
                child: Text(
                  widget.userName.isNotEmpty
                      ? widget.userName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    color: widget.themeData.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              SizedBox(width: MySize.size10),

              // Welcome text
              Text(
                AppLocalizations.of(context).translate('welcome') +
                    ' ${widget.userName}',
                style: AppTheme.getTextStyle(
                  widget.themeData.textTheme.titleMedium,
                  fontWeight: 700,
                  color: Colors.white,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}