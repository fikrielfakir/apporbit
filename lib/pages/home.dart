import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pos_final/pages/home/widgets/greeting_widget.dart';
import 'package:pos_final/pages/home/widgets/statistics_widget.dart';
import 'package:pos_final/pages/notifications/view_model_manger/notifications_cubit.dart';
import 'package:pos_final/pages/report.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../helpers/AppTheme.dart';
import '../helpers/SizeConfig.dart';
import '../helpers/icons.dart';
import '../helpers/otherHelpers.dart';
import '../locale/MyLocalizations.dart';
import '../models/attendance.dart';
import '../models/paymentDatabase.dart';
import '../models/sell.dart';
import '../models/sellDatabase.dart';
import '../models/system.dart';
import '../models/variations.dart';
import 'change_password_screen.dart';

class Home extends StatefulWidget {
  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  var user,
      note = new TextEditingController(),
      clockInTime = DateTime.now(),
      selectedLanguage;
  LatLng? currentLoc;

  String businessSymbol = '',
      businessLogo = '',
      defaultImage = 'assets/images/default_product.png',
      businessName = '',
      userName = '';

  double totalSalesAmount = 0.00,
      totalReceivedAmount = 0.00,
      totalDueAmount = 0.00,
      byCash = 0.00,
      byCard = 0.00,
      byCheque = 0.00,
      byBankTransfer = 0.00,
      byOther = 0.00,
      byCustomPayment_1 = 0.00,
      byCustomPayment_2 = 0.00,
      byCustomPayment_3 = 0.00;

  bool accessExpenses = false,
      attendancePermission = false,
      notPermitted = false,
      syncPressed = false;
  bool? checkedIn;

  Map<String, dynamic>? paymentMethods;
  int? totalSales;
  List<Map> method = [], payments = [];

  static int themeType = 1;
  ThemeData themeData = AppTheme.getThemeFromThemeMode(themeType);
  CustomAppTheme customAppTheme = AppTheme.getCustomAppTheme(themeType);

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    getPermission();
    homepageData();
    Helper().syncCallLogs();
  }

  homepageData() async {
    var prefs = await SharedPreferences.getInstance();
    user = await System().get('loggedInUser');
    userName = ((user['surname'] != null) ? user['surname'] : "") +
        ' ' +
        user['first_name'];
    await loadPaymentDetails();
    await Helper().getFormattedBusinessDetails().then((value) {
      businessSymbol = value['symbol'];
      businessLogo = value['logo'] ?? Config().defaultBusinessImage;
      businessName = value['name'];
      Config.quantityPrecision = value['quantityPrecision'] ?? 2;
      Config.currencyPrecision = value['currencyPrecision'] ?? 2;
    });
    selectedLanguage =
        prefs.getString('language_code') ?? Config().defaultLanguage;
    setState(() {});
  }

  checkIOButtonDisplay() async {
    await Attendance().getCheckInTime(Config.userId).then((value) {
      if (value != null) {
        clockInTime = DateTime.parse(value);
      }
    });
    var activeSubscriptionDetails = await System().get('active-subscription');
    if (activeSubscriptionDetails.length > 0 &&
        activeSubscriptionDetails[0].containsKey('package_details')) {
      Map<String, dynamic> packageDetails =
      activeSubscriptionDetails[0]['package_details'];
      if (packageDetails.containsKey('essentials_module') &&
          packageDetails['essentials_module'].toString() == '1') {
        checkedIn = await Attendance().getAttendanceStatus(Config.userId);
        setState(() {});
      } else {
        setState(() {
          checkedIn = null;
        });
      }
    } else {
      setState(() {
        checkedIn = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(),
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        title: Text(
          AppLocalizations.of(context).translate('home'),
          style: themeData.textTheme.headline6?.copyWith(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: Color(0xff9e1e63),
        actions: <Widget>[
          IconButton(
            icon: Icon(MdiIcons.send, color: Colors.white),
            onPressed: () async {
              (await Helper().checkConnectivity())
                  ? await sync()
                  : Fluttertoast.showToast(
                  msg: AppLocalizations.of(context)
                      .translate('check_connectivity'));
            },
          ),
          IconButton(
            icon: Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              SharedPreferences prefs = await SharedPreferences.getInstance();
              await SellDatabase().getNotSyncedSells().then((value) {
                if (value.isEmpty) {
                  prefs.setInt('prevUserId', Config.userId!);
                  prefs.remove('userId');
                  Navigator.pushReplacementNamed(context, '/login');
                } else {
                  Fluttertoast.showToast(
                      msg: AppLocalizations.of(context)
                          .translate('sync_all_sales_before_logout'));
                }
              });
            },
          ),
        ],
        leading: Row(
          children: [
            IconButton(
              icon: Icon(Icons.menu, color: Colors.white),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
            BlocBuilder<NotificationsCubit, NotificationsState>(
              builder: (context, state) {
                return Badge.count(
                  smallSize: 10,
                  largeSize: 15,
                  alignment: AlignmentDirectional.topEnd,
                  count: NotificationsCubit.get(context).notificationsCount,
                  child: IconButton(
                    icon: Icon(Icons.notifications, color: Colors.white),
                    onPressed: () {
                      Navigator.pushNamed(context, '/notify');
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: <Widget>[
              GreetingWidget(
                themeData: themeData,
                userName: userName,
              ),
              SizedBox(height: 20),

              // Statistics Cards
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildStatCard(
                      title: AppLocalizations.of(context).translate('number_of_sales'),
                      value: '$totalSales',
                      icon: Icons.shopping_cart,
                      color: Color(0xff4285F4),
                    ),
                    SizedBox(width: 12),
                    _buildStatCard(
                      title: AppLocalizations.of(context).translate('sales_amount'),
                      value: '$businessSymbol ${(totalSalesAmount)}',
                      icon: Icons.attach_money,
                      color: Color(0xff34A853),
                    ),
                    SizedBox(width: 12),
                    _buildStatCard(
                      title: AppLocalizations.of(context).translate('paid_amount'),
                      value: '$businessSymbol ${(totalReceivedAmount)}',
                      icon: Icons.payment,
                      color: Color(0xffFBBC05),
                    ),
                    SizedBox(width: 12),
                    _buildStatCard(
                      title: AppLocalizations.of(context).translate('due_amount'),
                      value: '$businessSymbol ${(totalDueAmount)}',
                      icon: Icons.money_off,
                      color: Color(0xffEA4335),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 24),

              // Quick Actions Grid
              GridView.count(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                childAspectRatio: 1.2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 10,
                children: [
                  _buildActionButton(
                    icon: Icons.language,
                    label: AppLocalizations.of(context).translate('language'),
                    onTap: () => _showLanguageDialog(context),
                  ),
                  _buildActionButton(
                    icon: Icons.money,
                    label: AppLocalizations.of(context).translate('expenses'),
                    onTap: () => _navigateToExpenses(context),
                  ),
                  _buildActionButton(
                    icon: Icons.people,
                    label: AppLocalizations.of(context).translate('contact_payment'),
                    onTap: () => _navigateToContactPayment(context),
                  ),
                  _buildActionButton(
                    icon: Icons.follow_the_signs,
                    label: AppLocalizations.of(context).translate('follow_ups'),
                    onTap: () => _navigateToFollowUps(context),
                  ),
                  _buildActionButton(
                    icon: Icons.local_shipping,
                    label: AppLocalizations.of(context).translate('shipment'),
                    onTap: () => Navigator.pushNamed(context, '/shipment'),
                  ),
                  _buildActionButton(
                    icon: Icons.bar_chart,
                    label: AppLocalizations.of(context).translate('reports'),
                    onTap: () => Navigator.pushNamed(context, ReportScreen.routeName),
                  ),
                ],
              ),

              SizedBox(height: 24),

              // Payment Details Section
              SizedBox(
                width: double.infinity,
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context).translate('payment_details'),
                          style: themeData.textTheme.subtitle1?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Color(0xff1c2f36),
                          ),
                        ),
                        SizedBox(height: 12),
                        if (method.isEmpty)
                          Text(
                            '-',
                            style: themeData.textTheme.caption,
                          ),
                        ...method.map((payment) => Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 4,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: Color(0xffbe185d),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    payment['key'],
                                    style: themeData.textTheme.bodyText1,
                                  ),
                                ],
                              ),
                              Text(
                                '$businessSymbol ${Helper().formatCurrency(payment['value'])}',
                                style: themeData.textTheme.bodyText1?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        )).toList(),
                      ],
                    ),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Container(
        color: Colors.white,
        child: Column(
          children: <Widget>[
            Container(
              height: MySize.scaleFactorHeight! * 200,
              decoration: BoxDecoration(
                color: Color(0xffefefef),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Center(
                child: Container(
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (businessLogo != null && businessLogo.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: 300,
                              maxHeight: 150,
                            ),
                            child: Image.network( // Changed from Image.asset to Image.network
                              businessLogo,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) => Icon(Icons.business),
                            ),
                          ),
                        ),
                      // Flexible(
                      //   child: Text(
                      //     businessName,
                      //     style: TextStyle(
                      //       color: Colors.white,
                      //       fontSize: 20,
                      //       fontWeight: FontWeight.bold,
                      //     ),
                      //     overflow: TextOverflow.ellipsis,
                      //     maxLines: 2,
                      //   ),
                      // ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 9,
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: <Widget>[
                  _drawerItem(
                    icon: Icons.language,
                    title: AppLocalizations.of(context).translate('language'),
                    onTap: () => _showLanguageDialog(context),
                  ),
                  if (accessExpenses)
                    _drawerItem(
                      icon: Icons.money,
                      title: AppLocalizations.of(context).translate('expenses'),
                      onTap: () => _navigateToExpenses(context),
                    ),
                  _drawerItem(
                    icon: Icons.payment,
                    title: AppLocalizations.of(context).translate('contact_payment'),
                    onTap: () => _navigateToContactPayment(context),
                  ),
                  _drawerItem(
                    icon: Icons.follow_the_signs,
                    title: AppLocalizations.of(context).translate('follow_ups'),
                    onTap: () => _navigateToFollowUps(context),
                  ),
                  if (Config().showFieldForce)
                    _drawerItem(
                      icon: MdiIcons.humanMale,
                      title: AppLocalizations.of(context).translate('field_force_visits'),
                      onTap: () => _navigateToFieldForce(context),
                    ),
                  _drawerItem(
                    icon: Icons.people,
                    title: AppLocalizations.of(context).translate('contacts'),
                    onTap: () => _navigateToContacts(context),
                  ),
                  _drawerItem(
                    icon: Icons.local_shipping,
                    title: AppLocalizations.of(context).translate('shipment'),
                    onTap: () => Navigator.pushNamed(context, '/shipment'),
                  ),
                  // Add Change Password button here
                  _drawerItem(
                    icon: Icons.lock,
                    title: AppLocalizations.of(context).translate('change_password'),
                    onTap: () async {
                      try {
                        final system = System();
                        final token = await system.getToken();
                        _navigateToChangePassword(context, token);
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to get authentication token')),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 1,
              child: Container(
                alignment: Alignment.bottomCenter,
                margin: EdgeInsets.all(10),
                child: Text(
                  AppLocalizations.of(context).translate('version'),
                  style: themeData.textTheme.caption,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: Color(0xb0414040),
      ),
      title: Text(
        title,
        style: themeData.textTheme.subtitle1?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: 150,
      padding: EdgeInsets.all(16),
      margin: EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          SizedBox(height: 16),
          Text(
            title,
            style: themeData.textTheme.caption?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: themeData.textTheme.headline6?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28, color: Color(0xa503232c)),
            SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: themeData.textTheme.caption?.copyWith(
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget changeAppLanguage() {
    var appLanguage = Provider.of<AppLanguage>(context);
    return Container(
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          dropdownColor: themeData.colorScheme.onPrimary,
          onChanged: (String? newValue) {
            appLanguage.changeLanguage(Locale(newValue!), newValue);
            selectedLanguage = newValue;
            Navigator.pop(context);
          },
          value: selectedLanguage,
          items: Config().lang.map<DropdownMenuItem<String>>((Map locale) {
            return DropdownMenuItem<String>(
              value: locale['languageCode'],
              child: Text(
                locale['name'],
                style: AppTheme.getTextStyle(
                  themeData.textTheme.subtitle1,
                  fontWeight: 600,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> sync() async {
    if (!syncPressed) {
      syncPressed = true;
      showDialog(
        barrierDismissible: true,
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                Container(
                  margin: EdgeInsets.only(left: 5),
                  child: Text(
                    AppLocalizations.of(context).translate('sync_in_progress'),
                  ),
                ),
              ],
            ),
          );
        },
      );
      await Sell().createApiSell(syncAll: true).then((value) async {
        await Variations().refresh().then((value) {
          Navigator.pop(context);
        });
      });
    }
  }

  Future<void> getPermission() async {
    List<PermissionStatus> status = [
      await Permission.location.status,
      await Permission.storage.status,
      await Permission.camera.status,
    ];
    notPermitted = status.contains(PermissionStatus.denied);
    await Helper()
        .getPermission('essentials.allow_users_for_attendance_from_api')
        .then((value) {
      if (value == true) {
        checkIOButtonDisplay();
        setState(() {
          attendancePermission = true;
        });
      } else {
        setState(() {
          checkedIn = null;
        });
      }
    });

    if (await Helper().getPermission('all_expense.access') ||
        await Helper().getPermission('view_own_expense')) {
      setState(() {
        accessExpenses = true;
      });
    }
  }

  Future<List> loadStatistics() async {
    List result = await SellDatabase().getSells();
    totalSales = result.length;
    setState(() {
      result.forEach((sell) async {
        List payment =
        await PaymentDatabase().get(sell['id'], allColumns: true);
        var paidAmount = 0.0;
        var returnAmount = 0.0;
        payment.forEach((element) {
          if (element['is_return'] == 0) {
            paidAmount += element['amount'];
            payments
                .add({'key': element['method'], 'value': element['amount']});
          } else {
            returnAmount += element['amount'];
          }
        });
        totalSalesAmount = (totalSalesAmount + sell['invoice_amount']);
        totalReceivedAmount =
        (totalReceivedAmount + (paidAmount - returnAmount));
        totalDueAmount = (totalDueAmount + sell['pending_amount']);
      });
    });
    return result;
  }

  Future<void> loadPaymentDetails() async {
    var paymentMethod = [];
    await System().get('payment_methods').then((value) {
      value.forEach((element) {
        element.forEach((k, v) {
          paymentMethod.add({'key': '$k', 'value': '$v'});
        });
      });
    });

    await loadStatistics().then((value) {
      Future.delayed(Duration(seconds: 1), () {
        payments.forEach((row) {
          if (row['key'] == 'cash') {
            byCash += row['value'];
          }
          if (row['key'] == 'card') {
            byCard += row['value'];
          }
          if (row['key'] == 'cheque') {
            byCheque += row['value'];
          }
          if (row['key'] == 'bank_transfer') {
            byBankTransfer += row['value'];
          }
          if (row['key'] == 'other') {
            byOther += row['value'];
          }
          if (row['key'] == 'custom_pay_1') {
            byCustomPayment_1 += row['value'];
          }
          if (row['key'] == 'custom_pay_2') {
            byCustomPayment_2 += row['value'];
          }
          if (row['key'] == 'custom_pay_3') {
            byCustomPayment_3 += row['value'];
          }
        });
        paymentMethod.forEach((row) {
          if (byCash > 0 && row['key'] == 'cash')
            method.add({'key': row['value'], 'value': byCash});
          if (byCard > 0 && row['key'] == 'card')
            method.add({'key': row['value'], 'value': byCard});
          if (byCheque > 0 && row['key'] == 'cheque')
            method.add({'key': row['value'], 'value': byCheque});
          if (byBankTransfer > 0 && row['key'] == 'bank_transfer')
            method.add({'key': row['value'], 'value': byBankTransfer});
          if (byOther > 0 && row['key'] == 'other')
            method.add({'key': row['value'], 'value': byOther});
          if (byCustomPayment_1 > 0 && row['key'] == 'custom_pay_1')
            method.add({'key': row['value'], 'value': byCustomPayment_1});
          if (byCustomPayment_2 > 0 && row['key'] == 'custom_pay_2')
            method.add({'key': row['value'], 'value': byCustomPayment_2});
          if (byCustomPayment_3 > 0 && row['key'] == 'custom_pay_3')
            method.add({'key': row['value'], 'value': byCustomPayment_3});
        });
        if (this.mounted) {
          setState(() {});
        }
      });
    });
  }

  void _showLanguageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          AppLocalizations.of(context).translate('language'),
          style: themeData.textTheme.subtitle1?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: changeAppLanguage(),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              AppLocalizations.of(context).translate('save'),
              style: TextStyle(color: Color(0xb0414040)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _navigateToExpenses(BuildContext context) async {
    if (await Helper().checkConnectivity()) {
      Navigator.pushNamed(context, '/expense');
    } else {
      Fluttertoast.showToast(
          msg: AppLocalizations.of(context).translate('check_connectivity'));
    }
  }

  Future<void> _navigateToContactPayment(BuildContext context) async {
    if (await Helper().checkConnectivity()) {
      Navigator.pushNamed(context, '/contactPayment');
    } else {
      Fluttertoast.showToast(
          msg: AppLocalizations.of(context).translate('check_connectivity'));
    }
  }

  Future<void> _navigateToFollowUps(BuildContext context) async {
    if (await Helper().checkConnectivity()) {
      Navigator.pushNamed(context, '/leads');
    } else {
      Fluttertoast.showToast(
          msg: AppLocalizations.of(context).translate('check_connectivity'));
    }
  }

  Future<void> _navigateToFieldForce(BuildContext context) async {
    if (await Helper().checkConnectivity()) {
      Navigator.pushNamed(context, '/fieldForce');
    } else {
      Fluttertoast.showToast(
          msg: AppLocalizations.of(context).translate('check_connectivity'));
    }
  }

  Future<void> _navigateToContacts(BuildContext context) async {
    if (await Helper().checkConnectivity()) {
      Navigator.pushNamed(context, '/leads');
    } else {
      Fluttertoast.showToast(
          msg: AppLocalizations.of(context).translate('check_connectivity'));
    }
  }
}
void _navigateToChangePassword(BuildContext context, String token) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => ChangePasswordScreen(
        token: token,
      ),
    ),
  );
}