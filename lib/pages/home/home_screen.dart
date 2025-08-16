
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pos_final/config.dart';
import 'package:pos_final/helpers/AppTheme.dart';
import 'package:pos_final/helpers/icons.dart';
import 'package:pos_final/locale/MyLocalizations.dart';
import 'package:pos_final/pages/notifications/view_model_manger/notifications_cubit.dart';
import 'package:pos_final/models/offline_manager.dart';
import 'widgets/greeting_widget.dart';
import 'widgets/statistics_widget.dart';
import 'widgets/daily_sales_card.dart';
import 'widgets/intelligent_alerts_widget.dart';
import 'package:pos_final/services/intelligent_alerts_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  static ThemeData themeData = AppTheme.getThemeFromThemeMode(1);
  static final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late AnimationController _animationController;
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;
  bool _isOfflineMode = false;
  Map<String, int> _cachedDataSummary = {};
  final IntelligentAlertsService _alertsService = IntelligentAlertsService();

  // Enhanced menu items with more features
  final List<MenuItemData> _menuItems = [
    MenuItemData(
      title: 'New Sale',
      subtitle: 'Create new transaction',
      icon: 'assets/images/payed_money.png',
      route: '/add-sale',
      color: Color(0xFF4C6FFF),
      iconData: Icons.add_shopping_cart,
      isMainAction: true,
    ),
    MenuItemData(
      title: 'Sales History',
      subtitle: 'View all sales',
      icon: 'assets/images/sales.png',
      route: '/sale',
      color: Color(0xFF00C851),
      iconData: Icons.history,
    ),
    MenuItemData(
      title: 'Products',
      subtitle: 'Manage inventory',
      icon: 'assets/images/default_product.png',
      route: '/products',
      color: Color(0xFFFF8A48),
      iconData: Icons.inventory_2,
    ),
    MenuItemData(
      title: 'Contacts',
      subtitle: 'Customer management',
      icon: 'assets/images/contact.png',
      route: '/leads',
      color: Color(0xFF41D37E),
      iconData: Icons.people,
      requiresConnectivity: true,
    ),
    MenuItemData(
      title: 'Expenses',
      subtitle: 'Track spending',
      icon: 'assets/images/money.png',
      route: '/expense',
      color: Color(0xFFE91E63),
      iconData: Icons.payment,
      requiresConnectivity: true,
    ),
    MenuItemData(
      title: 'Reports',
      subtitle: 'Analytics & insights',
      icon: 'assets/images/reports.png',
      route: '/report',
      color: Color(0xFFFFC107),
      iconData: Icons.analytics,
    ),
    MenuItemData(
      title: 'Shipments',
      subtitle: 'Delivery tracking',
      icon: 'assets/images/delivery.png',
      route: '/shipment',
      color: Color(0xFF6E62B6),
      iconData: Icons.local_shipping,
    ),
    MenuItemData(
      title: 'Settings',
      subtitle: 'App configuration',
      icon: 'assets/images/settings.png',
      route: '/settings',
      color: Color(0xFF78909C),
      iconData: Icons.settings,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _animationController.forward();
    _pulseController.repeat();
    _checkOfflineStatus();
    _loadCachedDataSummary();
    _loadAlerts();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _checkOfflineStatus() async {
    final offlineManager = OfflineManager();
    await offlineManager.initialize();
    setState(() {
      _isOfflineMode = offlineManager.isOfflineMode;
    });
  }

  Future<void> _loadCachedDataSummary() async {
    final offlineManager = OfflineManager();
    final summary = await offlineManager.getCachedDataSummary();
    setState(() {
      _cachedDataSummary = summary;
    });
  }

  Future<void> _loadAlerts() async {
    await _alertsService.checkAlerts();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _refreshData() async {
    await _loadCachedDataSummary();
    await _loadAlerts();
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Color(0xFFF8FAFC),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(
            child: Column(
              children: [
                // Greeting Section
                _buildGreetingSection(),

                // Offline Status Card
                if (_isOfflineMode) _buildOfflineStatusCard(),

                // Statistics Section
                _buildStatisticsSection(),

                // Daily Sales Card
                Container(
                  margin: EdgeInsets.symmetric(horizontal: 16),
                  child: DailySalesCard(themeData: themeData),
                ),

                // Intelligent Alerts
                IntelligentAlertsWidget(themeData: themeData),

                // Quick Actions Header
                _buildSectionHeader('Quick Actions', Icons.dashboard),

                // Main Action Button
                _buildMainActionButton(),

                // Menu Grid
                _buildMenuGrid(),

                // Recent Activity Section
                _buildSectionHeader('Recent Activity', Icons.history),
                _buildRecentActivitySection(),

                SizedBox(height: 100), // Space for FAB
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _buildEnhancedFAB(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: themeData.colorScheme.primary,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                themeData.colorScheme.primary,
                themeData.colorScheme.primary.withOpacity(0.8),
              ],
            ),
          ),
        ),
      ),
      title: Text(
        AppLocalizations.of(context).translate('home'),
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 18,
        ),
      ),
      actions: [
        // Sync Button with pulse animation
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Transform.scale(
              scale: 1.0 + (_pulseController.value * 0.1),
              child: IconButton(
                onPressed: _syncData,
                icon: Icon(Icons.sync, color: Colors.white),
              ),
            );
          },
        ),
        // Notifications with enhanced badge
        BlocBuilder<NotificationsCubit, NotificationsState>(
          builder: (context, state) {
            final notificationCount = NotificationsCubit.get(context).notificationsCount;
            final alertCount = _alertsService.highPriorityAlertCount;
            final totalCount = notificationCount + alertCount;

            return Stack(
              children: [
                IconButton(
                  onPressed: () => Navigator.pushNamed(context, '/notify'),
                  icon: Icon(IconBroken.Notification, color: Colors.white),
                ),
                if (totalCount > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: alertCount > 0 ? Colors.orange : Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        '$totalCount',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: Colors.white),
          onSelected: _handleMenuSelection,
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'profile',
              child: Row(
                children: [
                  Icon(Icons.person, size: 20),
                  SizedBox(width: 12),
                  Text('Profile'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout, size: 20),
                  SizedBox(width: 12),
                  Text('Logout'),
                ],
              ),
            ),
          ],
        ),
      ],
      leading: IconButton(
        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        icon: Icon(Icons.menu, color: Colors.white),
      ),
    );
  }

  Widget _buildGreetingSection() {
    return Container(
      margin: EdgeInsets.all(16),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: GreetingWidget(
          themeData: themeData,
          userName: 'User', // You can get this from user preferences
        ),
      ),
    );
  }

  Widget _buildOfflineStatusCard() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        elevation: 2,
        color: Colors.orange.shade50,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.cloud_off, color: Colors.orange, size: 24),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Offline Mode',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade800,
                      ),
                    ),
                    Text(
                      'Cached data: ${_cachedDataSummary.values.fold(0, (a, b) => a + b)} items',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: _syncData,
                child: Text('Sync'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatisticsSection() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      child: Statistics(
        themeData: themeData,
        totalSales: 0,
        totalReceivedAmount: 0,
        totalDueAmount: 0,
        totalSalesAmount: 0,
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Icon(icon, size: 24, color: themeData.colorScheme.primary),
          SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainActionButton() {
    final mainAction = _menuItems.firstWhere((item) => item.isMainAction);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Card(
              elevation: 8,
              shadowColor: mainAction.color.withOpacity(0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: InkWell(
                onTap: () => Navigator.pushNamed(context, mainAction.route),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: [
                        mainAction.color,
                        mainAction.color.withOpacity(0.8),
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          mainAction.iconData,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              mainAction.title,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              mainAction.subtitle,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.white,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMenuGrid() {
    final otherItems = _menuItems.where((item) => !item.isMainAction).toList();

    return Container(
      padding: EdgeInsets.all(16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.1,
        ),
        itemCount: otherItems.length,
        itemBuilder: (context, index) {
          final item = otherItems[index];
          return _buildEnhancedMenuItem(item, index);
        },
      ),
    );
  }

  Widget _buildEnhancedMenuItem(MenuItemData item, int index) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final delay = index * 0.1;
        final animation = Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Interval(delay, 1.0, curve: Curves.easeOut),
          ),
        );

        return Transform.translate(
          offset: Offset(0, 50 * (1 - animation.value)),
          child: Opacity(
            opacity: animation.value,
            child: Card(
              elevation: 3,
              shadowColor: item.color.withOpacity(0.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: InkWell(
                onTap: () => _handleMenuItemTap(item),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: item.color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          item.iconData,
                          color: item.color,
                          size: 28,
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        item.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 4),
                      Text(
                        item.subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (item.requiresConnectivity && _isOfflineMode)
                        Container(
                          margin: EdgeInsets.only(top: 4),
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Offline',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecentActivitySection() {
    return Container(
      margin: EdgeInsets.all(16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListView(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          children: [
            _buildActivityItem(
              Icons.shopping_cart,
              'New Sale',
              'Sale #1234 - \$150.00',
              '2 hours ago',
              Colors.green,
            ),
            Divider(height: 1),
            _buildActivityItem(
              Icons.inventory,
              'Product Added',
              'iPhone 15 Pro added to inventory',
              '5 hours ago',
              Colors.blue,
            ),
            Divider(height: 1),
            _buildActivityItem(
              Icons.people,
              'New Customer',
              'John Doe registered',
              '1 day ago',
              Colors.purple,
            ),
            Padding(
              padding: EdgeInsets.all(16),
              child: TextButton(
                onPressed: () => Navigator.pushNamed(context, '/sale'),
                child: Text('View All Activity'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(
      IconData icon,
      String title,
      String subtitle,
      String time,
      Color color,
      ) {
    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12)),
      trailing: Text(
        time,
        style: TextStyle(
          fontSize: 11,
          color: Colors.grey.shade600,
        ),
      ),
    );
  }

  Widget _buildEnhancedFAB() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: FloatingActionButton.extended(
              onPressed: () => Navigator.pushNamed(context, '/add-sale'),
              backgroundColor: themeData.colorScheme.primary,
              elevation: 6,
              label: Text(
                'Quick Sale',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              icon: Icon(Icons.add_shopping_cart),
            ),
          ),
          SizedBox(width: 16),
          FloatingActionButton(
            onPressed: () => _showQuickActionsBottomSheet(),
            backgroundColor: Colors.white,
            elevation: 6,
            child: Icon(
              Icons.more_horiz,
              color: themeData.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  void _handleMenuItemTap(MenuItemData item) {
    if (item.requiresConnectivity && _isOfflineMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${item.title} requires internet connection'),
          backgroundColor: Colors.orange,
          action: SnackBarAction(
            label: 'Go Online',
            onPressed: _syncData,
          ),
        ),
      );
      return;
    }
    Navigator.pushNamed(context, item.route);
  }

  void _handleMenuSelection(String value) {
    switch (value) {
      case 'profile':
      // Navigate to profile
        break;
      case 'logout':
      // Handle logout
        break;
    }
  }

  void _syncData() async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Syncing data...'),
        backgroundColor: themeData.colorScheme.primary,
      ),
    );

    // Refresh data after sync
    await _refreshData();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sync completed!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _showQuickActionsBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildQuickActionButton(
                  Icons.qr_code_scanner,
                  'Scan QR',
                      () => Navigator.pushNamed(context, '/qr-scan'),
                ),
                _buildQuickActionButton(
                  Icons.camera_alt,
                  'Add Product',
                      () => Navigator.pushNamed(context, '/add-product'),
                ),
                _buildQuickActionButton(
                  Icons.person_add,
                  'Add Contact',
                      () => Navigator.pushNamed(context, '/add-contact'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: themeData.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              color: themeData.colorScheme.primary,
              size: 24,
            ),
          ),
          SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// Enhanced data class for menu items
class MenuItemData {
  final String title;
  final String subtitle;
  final String icon;
  final String route;
  final Color color;
  final IconData iconData;
  final bool requiresConnectivity;
  final bool isMainAction;

  MenuItemData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
    required this.color,
    required this.iconData,
    this.requiresConnectivity = false,
    this.isMainAction = false,
  });
}
