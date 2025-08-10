import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pos_final/config.dart';
import 'package:pos_final/helpers/AppTheme.dart';
import 'package:pos_final/helpers/icons.dart';
import 'package:pos_final/locale/MyLocalizations.dart';
import 'package:pos_final/pages/notifications/view_model_manger/notifications_cubit.dart';
import 'widgets/greeting_widget.dart';
import 'widgets/statistics_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  static ThemeData themeData = AppTheme.getThemeFromThemeMode(1);
  static final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Menu items
  final List<MenuItemData> _menuItems = [
    MenuItemData(
      title: 'Payments',
      icon: 'assets/images/payed_money.png',
      route: '/sale',
      color: Color(0xFF4C6FFF),
    ),
    MenuItemData(
      title: 'Expenses',
      icon: 'assets/images/money.png',
      route: '/expense',
      color: Color(0xFFFF8A48),
      requiresConnectivity: true,
    ),
    MenuItemData(
      title: 'Contacts',
      icon: 'assets/images/contact.png',
      route: '/leads',
      color: Color(0xFF41D37E),
      requiresConnectivity: true,
    ),
    MenuItemData(
      title: 'Shipment',
      icon: 'assets/images/delivery.png',
      route: '/shipment',
      color: Color(0xFF6E62B6),
    ),
    MenuItemData(
      title: 'Reports',
      icon: 'assets/images/reports.png',
      route: '/report',
      color: Color(0xFFFFC107),
    ),
    MenuItemData(
      title: 'Settings',
      icon: 'assets/images/settings.png',
      route: '/settings',
      color: Color(0xFF78909C),
    ),
  ];

  // Animation controller for the card reveal
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: themeData.colorScheme.primary,
        centerTitle: true,
        title: Text(
          AppLocalizations.of(context).translate('home'),
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        actions: <Widget>[
          IconButton(
            onPressed: () async {
              // Sync functionality
            },
            icon: Icon(Icons.sync, color: Colors.white),
          ),
          IconButton(
            onPressed: () async {
              // Logout functionality
            },
            icon: Icon(IconBroken.Logout, color: Colors.white),
          ),
        ],
        leading: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: GestureDetector(
                child: Icon(Icons.menu, color: Colors.white),
                onTap: () => _scaffoldKey.currentState?.openDrawer(),
              ),
            ),
            SizedBox(width: 10),
            BlocBuilder<NotificationsCubit, NotificationsState>(
              builder: (context, state) {
                return Badge.count(
                  count: NotificationsCubit.get(context).notificationsCount,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pushNamed(context, '/notify');
                    },
                    child: Icon(
                      IconBroken.Notification,
                      color: Colors.white,
                    ),
                  ),
                );
              },
            )
          ],
        ),
        leadingWidth: 75,
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(4),
          child: Container(
            height: 4,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  themeData.colorScheme.primary,
                  themeData.colorScheme.secondary,
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Greeting Widget
            GreetingWidget(themeData: themeData, userName: 'Shehab'),

            // Statistics Section
            Statistics(
              themeData: themeData,
              totalSales: 0,
              totalReceivedAmount: 0,
              totalDueAmount: 0,
              totalSalesAmount: 0,
            ),

            // Quick Actions Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),

            // Menu Grid
            Padding(
              padding: const EdgeInsets.all(16),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.9,
                ),
                itemCount: _menuItems.length,
                itemBuilder: (context, index) {
                  final item = _menuItems[index];

                  // Animation for each menu item
                  return AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      final delay = index * 0.2;
                      final start = 0.2 + delay;
                      final end = 0.5 + delay;

                      final curvedAnimation = CurvedAnimation(
                        parent: _animationController,
                        curve: Interval(
                          start.clamp(0.0, 1.0),
                          end.clamp(0.0, 1.0),
                          curve: Curves.easeOut,
                        ),
                      );

                      return Transform.scale(
                        scale: Tween<double>(begin: 0.8, end: 1.0)
                            .evaluate(curvedAnimation),
                        child: Opacity(
                          opacity: curvedAnimation.value,
                          child: child,
                        ),
                      );
                    },
                    child: _buildMenuItem(item),
                  );
                },
              ),
            ),

            // Additional sections can be added here
            SizedBox(height: 20),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Navigate to POS or sales screen
          Navigator.pushNamed(context, '/add-sale');
        },
        backgroundColor: themeData.colorScheme.primary,
        label: Text('New Sale'),
        icon: Icon(Icons.add_shopping_cart),
      ),
    );
  }

  Widget _buildMenuItem(MenuItemData item) {
    return Card(
      elevation: 2,
      shadowColor: item.color.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () async {
          // Navigate to the route or check connectivity
          Navigator.pushNamed(context, item.route);
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: item.color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: ImageIcon(
                AssetImage(item.icon),
                color: item.color,
                size: 28,
              ),
            ),
            SizedBox(height: 8),
            Text(
              item.title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// Data class for menu items
class MenuItemData {
  final String title;
  final String icon;
  final String route;
  final Color color;
  final bool requiresConnectivity;

  MenuItemData({
    required this.title,
    required this.icon,
    required this.route,
    required this.color,
    this.requiresConnectivity = false,
  });
}