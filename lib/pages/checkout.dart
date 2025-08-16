import 'dart:async';
import 'dart:convert';
import 'package:date_time_picker/date_time_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:pos_final/config.dart';
import 'package:geolocator/geolocator.dart';

import '../helpers/AppTheme.dart';
import '../helpers/SizeConfig.dart';
import '../helpers/otherHelpers.dart';
import '../locale/MyLocalizations.dart';
import '../models/offline_manager.dart';
import '../models/paymentDatabase.dart';
import '../models/sell.dart';
import '../models/sellDatabase.dart';
import '../models/system.dart';
import 'login.dart';

class CheckOut extends StatefulWidget {
  @override
  CheckOutState createState() => CheckOutState();
}

class CheckOutState extends State<CheckOut> {
  List<Map> paymentMethods = [];
  int? sellId;
  double totalPaying = 0.0;
  String symbol = '',
      invoiceType = "Mobile",
      transactionDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
  Map? argument;
  List<Map> payments = [], paymentAccounts = [{'id': null, 'name': "None"}];
  List<int> deletedPaymentId = [];
  late Map<String, dynamic> paymentLine;
  List sellDetail = [];
  double invoiceAmount = 0.00, pendingAmount = 0.00, changeReturn = 0.00;
  double returnAmount = 0.00;
  TextEditingController dateController = TextEditingController(),
      saleNote = TextEditingController(),
      staffNote = TextEditingController(),
      shippingDetails = TextEditingController(),
      shippingCharges = TextEditingController(),
      returnAmountController = TextEditingController();
  bool _printInvoice = true,
      printWebInvoice = false,
      saleCreated = false,
      isLoading = false;
  static int themeType = 1;
  ThemeData themeData = AppTheme.getThemeFromThemeMode(themeType);
  CustomAppTheme customAppTheme = AppTheme.getCustomAppTheme(themeType);
  double? longitude;
  double? latitude;
  bool isLocationFetched = false;

  @override
  void initState() {
    super.initState();
    getInitDetails();
    getLocation();
  }

  Future<void> getLocation() async {
    try {
      bool serviceEnabled;
      LocationPermission permission;

      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          isLocationFetched = true; // Allow checkout without location
        });
        return;
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            isLocationFetched = true; // Allow checkout without location
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          isLocationFetched = true; // Allow checkout without location
        });
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10));
      setState(() {
        longitude = position.longitude;
        latitude = position.latitude;
        isLocationFetched = true;
      });

      await saveLocationToDatabase(latitude, longitude);
    } catch (e) {
      print('Location error: $e');
      setState(() {
        isLocationFetched = true; // Allow checkout even if location fails
      });
    }
  }

  Future<void> saveLocationToDatabase(double? lat, double? lon) async {
    print('Location saved to database: Latitude: $lat, Longitude: $lon');
  }

  getInitDetails() async {
    setState(() {
      isLoading = true;
    });
    await Helper().getFormattedBusinessDetails().then((value) {
      symbol = value['symbol'];
    });
  }

  setPaymentAccounts() async {
    try {
      List payments = await System().get('payment_method', argument!['locationId']);
      await System().getPaymentAccounts().then((value) {
        for (var element in value) {
          List<String> accIds = [];
          for (var paymentMethod in payments) {
            if ((paymentMethod['account_id'].toString() == element['id'].toString()) &&
                !accIds.contains(element['id'].toString())) {
              setState(() {
                paymentAccounts.add({'id': element['id'], 'name': element['name']});
              });
              accIds.add(element['id'].toString());
            }
          }
        }
      });
    } catch (e) {
      print('Error setting payment accounts: $e');
    }
  }

  @override
  void didChangeDependencies() {
    argument = ModalRoute.of(context)!.settings.arguments as Map?;
    if (argument != null) {
      invoiceAmount = argument!['invoiceAmount'] ?? 0.0;
      setPaymentAccounts().then((value) {
        if (argument!['sellId'] == null) {
          setPaymentDetails().then((value) {
            if (paymentMethods.isNotEmpty) {
              payments.add({
                'amount': invoiceAmount,
                'method': paymentMethods[0]['name'],
                'note': '',
                'account_id': paymentMethods[0]['account_id']
              });
              calculateMultiPayment();
            }
          });
        } else {
          setPaymentDetails().then((value) {
            onEdit(argument!['sellId']);
          });
        }
      });
      setState(() {
        isLoading = false;
      });
    }
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    staffNote.dispose();
    saleNote.dispose();
    returnAmountController.dispose();
    shippingDetails.dispose();
    shippingCharges.dispose();
    dateController.dispose();
    super.dispose();
  }

  onEdit(sellId) async {
    try {
      sellDetail = await SellDatabase().getSellBySellId(sellId);
      this.sellId = argument!['sellId'];

      if (sellDetail.isNotEmpty) {
        var sellData = sellDetail[0];
        shippingCharges.text = sellData['shipping_charges']?.toString() ?? '0';
        shippingDetails.text = sellData['shipping_details'] ?? '';
        saleNote.text = sellData['sale_note'] ?? '';
        staffNote.text = sellData['staff_note'] ?? '';
        returnAmountController.text = sellData['return_amount']?.toString() ?? '0';
        returnAmount = double.tryParse(sellData['return_amount']?.toString() ?? '0') ?? 0.0;
      }

      payments = [];
      List paymentLines = await PaymentDatabase().get(sellId, allColumns: true);
      for (var element in paymentLines) {
        if (element['is_return'] == 0) {
          payments.add({
            'id': element['id'],
            'amount': double.tryParse(element['amount'].toString()) ?? 0.0,
            'method': element['method'],
            'note': element['note'] ?? '',
            'account_id': element['account_id']
          });
        }
      }
      calculateMultiPayment();
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Error in onEdit: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          elevation: 0,
          title: Text(AppLocalizations.of(context).translate('checkout'),
              style: AppTheme.getTextStyle(themeData.textTheme.headline6,
                  fontWeight: 600)),
        ),
        body: SingleChildScrollView(
          child: (isLoading)
              ? Helper().loadingIndicator(context)
              : Column(
            children: [
              if (latitude != null && longitude != null)
                Padding(
                  padding: EdgeInsets.all(MySize.size16!),
                  child: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.location_on, color: Colors.green, size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Location: ${latitude!.toStringAsFixed(4)}, ${longitude!.toStringAsFixed(4)}',
                            style: TextStyle(fontSize: 12, color: Colors.green[700]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              paymentBox(),
            ],
          ),
        ));
  }

  Widget paymentBox() {
    return Container(
      margin: EdgeInsets.all(MySize.size3!),
      child: Column(
        children: <Widget>[
          Card(
            margin: EdgeInsets.all(MySize.size5!),
            shadowColor: Colors.blue,
            child: DateTimePicker(
              use24HourFormat: true,
              locale: Locale('en', 'US'),
              initialValue: transactionDate,
              type: DateTimePickerType.dateTime,
              firstDate: DateTime.now().subtract(Duration(days: 366)),
              lastDate: DateTime.now(),
              dateLabelText: "${AppLocalizations.of(context).translate('date')}:",
              style: AppTheme.getTextStyle(
                themeData.textTheme.bodyText1,
                fontWeight: 700,
                color: themeData.colorScheme.primary,
              ),
              textAlign: TextAlign.center,
              onChanged: (val) {
                setState(() {
                  transactionDate = val;
                });
              },
            ),
          ),
          ListView.builder(
              physics: ScrollPhysics(),
              shrinkWrap: true,
              itemCount: payments.length,
              itemBuilder: (context, index) {
                return Card(
                  margin: EdgeInsets.all(MySize.size5!),
                  shadowColor: Colors.blue,
                  child: Padding(
                    padding: EdgeInsets.all(MySize.size8!),
                    child: Column(children: <Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                  AppLocalizations.of(context).translate('amount') + ' : ',
                                  style: AppTheme.getTextStyle(
                                      themeData.textTheme.bodyText1,
                                      color: themeData.colorScheme.onBackground,
                                      fontWeight: 600,
                                      muted: true)),
                              SizedBox(
                                  height: MySize.size40,
                                  width: MySize.safeWidth! * 0.50,
                                  child: TextFormField(
                                      decoration: InputDecoration(
                                        suffix: Text(symbol),
                                      ),
                                      textAlign: TextAlign.center,
                                      initialValue: payments[index]['amount'].toStringAsFixed(2),
                                      inputFormatters: [
                                        FilteringTextInputFormatter(
                                            RegExp(r'^(\d+)?\.?\d{0,2}'),
                                            allow: true)
                                      ],
                                      keyboardType: TextInputType.number,
                                      onChanged: (value) {
                                        payments[index]['amount'] = Helper().validateInput(value);
                                        calculateMultiPayment();
                                      }))
                            ],
                          ),
                        ],
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: MySize.size6!),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            children: <Widget>[
                              Text(
                                  AppLocalizations.of(context).translate('payment_method') + ' : ',
                                  style: AppTheme.getTextStyle(
                                      themeData.textTheme.bodyText1,
                                      color: themeData.colorScheme.onBackground,
                                      fontWeight: 600,
                                      muted: true)),
                              DropdownButtonHideUnderline(
                                child: DropdownButton(
                                    dropdownColor: Colors.white,
                                    icon: Icon(Icons.arrow_drop_down),
                                    value: payments[index]['method'],
                                    items: paymentMethods.map<DropdownMenuItem<String>>((Map value) {
                                      return DropdownMenuItem<String>(
                                        value: value['name'],
                                        child: Container(
                                          width: MySize.screenWidth! * 0.35,
                                          child: Text(value['value'],
                                              softWrap: true,
                                              overflow: TextOverflow.ellipsis,
                                              style: AppTheme.getTextStyle(
                                                  themeData.textTheme.bodyText1,
                                                  color: themeData.colorScheme.onBackground,
                                                  fontWeight: 800,
                                                  muted: true)),
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (newValue) {
                                      for (var element in paymentMethods) {
                                        if (element['name'] == newValue) {
                                          setState(() {
                                            payments[index]['method'] = newValue;
                                            payments[index]['account_id'] = element['account_id'];
                                          });
                                        }
                                      }
                                    }),
                              )
                            ],
                          ),
                          Column(
                            children: <Widget>[
                              Text(
                                  AppLocalizations.of(context).translate('payment_account') + ' : ',
                                  style: AppTheme.getTextStyle(
                                      themeData.textTheme.bodyText1,
                                      color: themeData.colorScheme.onBackground,
                                      fontWeight: 600,
                                      muted: true)),
                              DropdownButtonHideUnderline(
                                child: DropdownButton(
                                    dropdownColor: Colors.white,
                                    icon: Icon(Icons.arrow_drop_down),
                                    value: payments[index]['account_id'],
                                    items: paymentAccounts.map<DropdownMenuItem<int>>((Map value) {
                                      return DropdownMenuItem<int>(
                                        value: value['id'],
                                        child: Container(
                                          width: MySize.screenWidth! * 0.35,
                                          child: Text(value['name'],
                                              softWrap: true,
                                              overflow: TextOverflow.ellipsis,
                                              style: AppTheme.getTextStyle(
                                                  themeData.textTheme.bodyText1,
                                                  color: themeData.colorScheme.onBackground,
                                                  fontWeight: 800,
                                                  muted: true)),
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (newValue) {
                                      setState(() {
                                        payments[index]['account_id'] = newValue;
                                      });
                                    }),
                              )
                            ],
                          ),
                        ],
                      ),
                      Row(
                        children: <Widget>[
                          SizedBox(
                            width: MySize.safeWidth! * 0.8,
                            child: TextFormField(
                                initialValue: payments[index]['note'],
                                decoration: InputDecoration(
                                    hintText:
                                    AppLocalizations.of(context).translate('payment_note')),
                                onChanged: (value) {
                                  payments[index]['note'] = value;
                                }),
                          ),
                          Expanded(
                              child: (index > 0)
                                  ? IconButton(
                                  icon: Icon(
                                    MdiIcons.deleteForeverOutline,
                                    size: MySize.size40,
                                    color: Colors.red,
                                  ),
                                  onPressed: () {
                                    alertConfirm(context, index);
                                  })
                                  : Container())
                        ],
                      ),
                    ]),
                  ),
                );
              }),
          Card(
            margin: EdgeInsets.all(MySize.size5!),
            child: Container(
              padding: EdgeInsets.all(MySize.size5!),
              child: Column(
                children: <Widget>[
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: themeData.colorScheme.primary),
                    ),
                    onPressed: () {
                      if (paymentMethods.isNotEmpty) {
                        setState(() {
                          payments.add({
                            'amount': pendingAmount,
                            'method': paymentMethods[0]['name'],
                            'note': '',
                            'account_id': paymentMethods[0]['account_id'],
                          });
                          calculateMultiPayment();
                        });
                      }
                    },
                    child: Text(
                      AppLocalizations.of(context).translate('add_payment'),
                      style: AppTheme.getTextStyle(
                        themeData.textTheme.subtitle1,
                        fontWeight: 700,
                        color: themeData.colorScheme.primary,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                        Text(
                            AppLocalizations.of(context).translate('shipping_charges') + ' : ',
                            style: AppTheme.getTextStyle(
                                themeData.textTheme.bodyText1,
                                color: themeData.colorScheme.onBackground,
                                fontWeight: 600,
                                muted: true)),
                        SizedBox(
                            height: MySize.size40,
                            width: MySize.safeWidth! * 0.5,
                            child: TextFormField(
                                controller: shippingCharges,
                                decoration: InputDecoration(suffix: Text(symbol)),
                                textAlign: TextAlign.center,
                                inputFormatters: [
                                  FilteringTextInputFormatter(
                                      RegExp(r'^(\d+)?\.?\d{0,2}'),
                                      allow: true)
                                ],
                                keyboardType: TextInputType.number,
                                onChanged: (value) {
                                  double shippingAmount = Helper().validateInput(value);
                                  invoiceAmount = (argument!['invoiceAmount'] ?? 0.0) + shippingAmount;
                                  calculateMultiPayment();
                                })),
                        Padding(padding: EdgeInsets.symmetric(vertical: 5)),
                        SizedBox(
                          width: MySize.safeWidth! * 0.8,
                          child: TextFormField(
                              controller: shippingDetails,
                              decoration: InputDecoration(
                                  hintText: AppLocalizations.of(context)
                                      .translate('shipping_details')),
                              onChanged: (value) async {}),
                        ),
                      ]),
                    ],
                  ),
                  Row(
                    children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                        Text(
                            AppLocalizations.of(context).translate('return_amount') + ' : ',
                            style: AppTheme.getTextStyle(
                                themeData.textTheme.bodyText1,
                                color: themeData.colorScheme.onBackground,
                                fontWeight: 600,
                                muted: true)),
                        SizedBox(
                            height: MySize.size40,
                            width: MySize.safeWidth! * 0.5,
                            child: TextFormField(
                                controller: returnAmountController,
                                decoration: InputDecoration(suffix: Text(symbol)),
                                textAlign: TextAlign.center,
                                inputFormatters: [
                                  FilteringTextInputFormatter(
                                      RegExp(r'^(\d+)?\.?\d{0,2}'),
                                      allow: true)
                                ],
                                keyboardType: TextInputType.number,
                                onChanged: (value) {
                                  returnAmount = Helper().validateInput(value);
                                  calculateMultiPayment();
                                })),
                      ]),
                    ],
                  ),
                  Container(
                    child: GridView.count(
                        shrinkWrap: true,
                        physics: ClampingScrollPhysics(),
                        crossAxisCount: 2,
                        padding: EdgeInsets.only(
                            left: MySize.size16!,
                            right: MySize.size16!,
                            top: MySize.size16!),
                        mainAxisSpacing: MySize.size16!,
                        childAspectRatio: 8 / 3,
                        crossAxisSpacing: MySize.size16!,
                        children: <Widget>[
                          block(
                            amount: Helper().formatCurrency(invoiceAmount - returnAmount),
                            subject: AppLocalizations.of(context).translate('total_payble') + ' : ',
                            backgroundColor: Colors.blue,
                            textColor: themeData.colorScheme.onBackground,
                          ),
                          block(
                            amount: Helper().formatCurrency(totalPaying),
                            subject: AppLocalizations.of(context).translate('total_paying') + ' : ',
                            backgroundColor: Colors.red,
                            textColor: themeData.colorScheme.onBackground,
                          ),
                          block(
                            amount: Helper().formatCurrency(changeReturn),
                            subject: AppLocalizations.of(context).translate('change_return') + ' : ',
                            backgroundColor: Colors.green,
                            textColor: (changeReturn >= 0.01)
                                ? Colors.red
                                : themeData.colorScheme.onBackground,
                          ),
                          block(
                            amount: Helper().formatCurrency(pendingAmount),
                            subject: AppLocalizations.of(context).translate('balance') + ' : ',
                            backgroundColor: Colors.orange,
                            textColor: (pendingAmount >= 0.01)
                                ? Colors.red
                                : themeData.colorScheme.onBackground,
                          ),
                          block(
                            amount: Helper().formatCurrency(returnAmount),
                            subject: AppLocalizations.of(context).translate('return_amount') + ' : ',
                            backgroundColor: Colors.orange,
                            textColor: (returnAmount >= 0.01)
                                ? Colors.lightGreen
                                : themeData.colorScheme.onBackground,
                          ),
                        ]),
                  ),
                  Padding(
                    padding: EdgeInsets.all(MySize.size8!),
                    child: Column(
                      children: <Widget>[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Column(children: <Widget>[
                              Text(
                                  AppLocalizations.of(context).translate('sell_note') + ' : ',
                                  style: AppTheme.getTextStyle(
                                      themeData.textTheme.bodyText1,
                                      color: themeData.colorScheme.onBackground,
                                      fontWeight: 600,
                                      muted: true)),
                              SizedBox(
                                  height: MySize.size80,
                                  width: MySize.screenWidth! * 0.40,
                                  child: TextFormField(controller: saleNote))
                            ]),
                            Column(
                              children: <Widget>[
                                Text(
                                    AppLocalizations.of(context).translate('staff_note') + ' : ',
                                    style: AppTheme.getTextStyle(
                                        themeData.textTheme.bodyText1,
                                        color: themeData.colorScheme.onBackground,
                                        fontWeight: 600,
                                        muted: true)),
                                SizedBox(
                                  height: MySize.size80,
                                  width: MySize.screenWidth! * 0.40,
                                  child: TextFormField(controller: staffNote),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Container(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                flex: 1,
                                child: Row(
                                  children: [
                                    Radio(
                                      value: "Mobile",
                                      groupValue: invoiceType,
                                      onChanged: (value) {
                                        setState(() {
                                          invoiceType = value.toString();
                                          printWebInvoice = false;
                                        });
                                      },
                                      toggleable: true,
                                    ),
                                    Expanded(
                                      child: Text(
                                        AppLocalizations.of(context).translate('mobile_layout'),
                                        maxLines: 2,
                                        style: AppTheme.getTextStyle(
                                            themeData.textTheme.bodyText2,
                                            color: themeData.colorScheme.onBackground,
                                            fontWeight: 600),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Row(
                                  children: [
                                    Radio(
                                      value: "Web",
                                      groupValue: invoiceType,
                                      onChanged: (value) async {
                                        if (await Helper().checkConnectivity()) {
                                          setState(() {
                                            invoiceType = value.toString();
                                            printWebInvoice = true;
                                          });
                                        } else {
                                          Fluttertoast.showToast(
                                              msg: AppLocalizations.of(context)
                                                  .translate('check_connectivity'));
                                        }
                                      },
                                      toggleable: true,
                                    ),
                                    Expanded(
                                      child: Text(
                                        AppLocalizations.of(context).translate('web_layout'),
                                        maxLines: 2,
                                        style: AppTheme.getTextStyle(
                                            themeData.textTheme.bodyText2,
                                            color: themeData.colorScheme.onBackground,
                                            fontWeight: 600),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              flex: 1,
                              child: Visibility(
                                visible: isLocationFetched,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                      primary: themeData.colorScheme.onPrimary, elevation: 5),
                                  onPressed: () {
                                    _printInvoice = false;
                                    if (pendingAmount >= 0.01) {
                                      alertPending(context);
                                    } else {
                                      if (!saleCreated) {
                                        onSubmit();
                                      }
                                    }
                                  },
                                  child: Text(
                                    AppLocalizations.of(context).translate('finalize_n_share'),
                                    style: AppTheme.getTextStyle(
                                      themeData.textTheme.subtitle1,
                                      fontWeight: 700,
                                      color: themeData.colorScheme.primary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: MySize.size10!),
                            ),
                            Expanded(
                              flex: 1,
                              child: Visibility(
                                visible: isLocationFetched,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                      primary: themeData.colorScheme.primary, elevation: 5),
                                  onPressed: () {
                                    _printInvoice = true;
                                    if (pendingAmount >= 0.01) {
                                      alertPending(context);
                                    } else {
                                      if (!saleCreated) {
                                        onSubmit();
                                      }
                                    }
                                  },
                                  child: Text(
                                    AppLocalizations.of(context).translate('finalize_n_print'),
                                    style: AppTheme.getTextStyle(
                                      themeData.textTheme.subtitle1,
                                      fontWeight: 700,
                                      color: themeData.colorScheme.onPrimary,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          ],
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  block({Color? backgroundColor, String? subject, amount, Color? textColor}) {
    ThemeData themeData = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAliasWithSaveLayer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MySize.size8!),
      ),
      child: Container(
        height: MySize.size30,
        child: Container(
          padding: EdgeInsets.all(MySize.size2!),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Text(
                subject!,
                style: AppTheme.getTextStyle(themeData.textTheme.bodyText1,
                    color: themeData.colorScheme.onBackground,
                    fontWeight: 800,
                    fontSize: 10,
                    muted: true),
              ),
              Text(
                " $amount $symbol",
                overflow: TextOverflow.ellipsis,
                style: AppTheme.getTextStyle(themeData.textTheme.bodyText1,
                    color: textColor, fontWeight: 600, muted: true),
              ),
            ],
          ),
        ),
      ),
    );
  }

  calculateMultiPayment() {
    totalPaying = 0.0;
    for (var element in payments) {
      totalPaying += double.tryParse(element['amount'].toString()) ?? 0.0;
    }

    // Get return amount from controller
    returnAmount = double.tryParse(returnAmountController.text) ?? 0.0;

    // Adjust invoice amount with shipping and return amount
    double shippingAmount = double.tryParse(shippingCharges.text) ?? 0.0;
    double adjustedInvoiceAmount = (argument!['invoiceAmount'] ?? 0.0) + shippingAmount - returnAmount;

    if (totalPaying > adjustedInvoiceAmount) {
      changeReturn = totalPaying - adjustedInvoiceAmount;
      pendingAmount = 0.0;
    } else if (adjustedInvoiceAmount > totalPaying) {
      pendingAmount = adjustedInvoiceAmount - totalPaying;
      changeReturn = 0.0;
    } else {
      pendingAmount = 0.0;
      changeReturn = 0.0;
    }

    // Update invoice amount for display
    invoiceAmount = adjustedInvoiceAmount;

    if (mounted) {
      setState(() {});
    }
  }

  setPaymentDetails() async {
    try {
      List payments = await System().get('payment_method', argument!['locationId']);
      for (var element in payments) {
        if (this.mounted) {
          setState(() {
            paymentMethods.add({
              'name': element['name'],
              'value': element['label'],
              'account_id': (element['account_id'] != null)
                  ? int.parse(element['account_id'].toString())
                  : null
            });
          });
        }
      }
    } catch (e) {
      print('Error setting payment details: $e');
    }
  }

  onSubmit() async {
    setState(() {
      isLoading = true;
      saleCreated = true;
    });

    try {
      // Validate inputs
      if (payments.isEmpty) {
        throw Exception('At least one payment method is required');
      }

      // Get return amount from controller
      returnAmount = double.tryParse(returnAmountController.text) ?? 0.0;

      // Check connectivity and offline mode
      bool hasConnectivity = await Helper().checkConnectivity();
      bool isOfflineMode = await OfflineManager().isOfflineMode;

      Map<String, dynamic> sell = await Sell().createSell(
          invoiceNo: Config.userId.toString() + "_" + DateFormat('yMdHm').format(DateTime.now()),
          transactionDate: transactionDate,
          changeReturn: changeReturn,
          contactId: argument!['customerId'],
          discountAmount: argument!['discountAmount'] ?? 0.0,
          discountType: argument!['discountType'] ?? 'fixed',
          invoiceAmount: invoiceAmount,
          locId: argument!['locationId'],
          pending: pendingAmount,
          saleNote: saleNote.text,
          saleStatus: 'final',
          sellId: sellId,
          latiTude: latitude,
          longiTude: longitude,
          shippingCharges: double.tryParse(shippingCharges.text) ?? 0.0,
          shippingDetails: shippingDetails.text,
          staffNote: staffNote.text,
          taxId: argument!['taxId'],
          isQuotation: 0,
          returnAmount: returnAmount);

      var response;
      if (sellId != null) {
        response = sellId;
        await SellDatabase().updateSells(sellId, sell).then((value) async {

          // Queue for sync if offline
          if (!hasConnectivity || isOfflineMode) {
            await OfflineManager().queueOfflineAction('update_sale', {
              'sell_id': sellId,
              'sell_data': sell,
              'payments': payments,
            });
          }

          for (var element in payments) {
            if (element['id'] != null) {
              paymentLine = {
                'amount': double.tryParse(element['amount'].toString()) ?? 0.0,
                'method': element['method'],
                'note': element['note'] ?? '',
                'account_id': element['account_id']
              };
              PaymentDatabase().updateEditedPaymentLine(element['id'], paymentLine);
            } else {
              paymentLine = {
                'sell_id': sellId,
                'method': element['method'],
                'amount': double.tryParse(element['amount'].toString()) ?? 0.0,
                'note': element['note'] ?? '',
                'account_id': element['account_id']
              };
              PaymentDatabase().store(paymentLine);
            }
          }
          if (deletedPaymentId.isNotEmpty) {
            PaymentDatabase().deletePaymentLineByIds(deletedPaymentId);
          }
          if (hasConnectivity && !isOfflineMode) {
            await Sell().createApiSell(sellId: sellId).then((value) => printOption(response));
          } else {
            printOption(response);
          }
        });
      } else {
        response = await SellDatabase().storeSell(sell);
        Sell().makePayment(payments, response);
        SellDatabase().updateSellLine({'sell_id': response, 'is_completed': 1});
        if (hasConnectivity && !isOfflineMode) {
          await Sell().createApiSell(sellId: response);
        }
        printOption(response);
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        saleCreated = false;
      });
      Fluttertoast.showToast(msg: 'Error: ${e.toString()}');
    }
  }

  printOption(sellId) async {
    Timer(Duration(seconds: 2), () async {
      try {
        List sellDetail = await SellDatabase().getSellBySellId(sellId);
        String? invoice = sellDetail.isNotEmpty ? sellDetail[0]['invoice_url'] : null;
        String invoiceNo = sellDetail.isNotEmpty ? sellDetail[0]['invoice_no'] ?? '' : '';

        if (_printInvoice) {
          if (printWebInvoice && invoice != null) {
            final response = await http.Client().get(Uri.parse(invoice));
            if (response.statusCode == 200) {
              await Helper()
                  .printDocument(sellId, argument!['taxId'], context, invoice: response.body)
                  .then((value) {
                Navigator.pushNamedAndRemoveUntil(
                    context,
                    (argument!['sellId'] == null) ? '/layout' : '/sale',
                    ModalRoute.withName('/home'));
              });
            } else {
              await Helper()
                  .printDocument(sellId, argument!['taxId'], context)
                  .then((value) {
                Navigator.pushNamedAndRemoveUntil(
                    context,
                    (argument!['sellId'] == null) ? '/layout' : '/sale',
                    ModalRoute.withName('/home'));
              });
            }
          } else {
            Helper().printDocument(sellId, argument!['taxId'], context).then((value) {
              Navigator.pushNamedAndRemoveUntil(
                  context,
                  (argument!['sellId'] == null) ? '/layout' : '/sale',
                  ModalRoute.withName('/home'));
            });
          }
        } else {
          if (printWebInvoice && invoice != null) {
            final response = await http.Client().get(Uri.parse(invoice));
            if (response.statusCode == 200) {
              await Helper()
                  .savePdf(sellId, argument!['taxId'], context, invoiceNo, invoice: response.body)
                  .then((value) {
                Navigator.pushNamedAndRemoveUntil(
                    context,
                    (argument!['sellId'] == null) ? '/layout' : '/sale',
                    ModalRoute.withName('/home'));
              });
            } else {
              await Helper()
                  .savePdf(sellId, argument!['taxId'], context, invoiceNo)
                  .then((value) {
                Navigator.pushNamedAndRemoveUntil(
                    context,
                    (argument!['sellId'] == null) ? '/layout' : '/sale',
                    ModalRoute.withName('/home'));
              });
            }
          } else {
            Helper().savePdf(sellId, argument!['taxId'], context, invoiceNo).then((value) {
              Navigator.pushNamedAndRemoveUntil(
                  context,
                  (argument!['sellId'] == null) ? '/layout' : '/sale',
                  ModalRoute.withName('/home'));
            });
          }
        }
      } catch (e) {
        print('Error in printOption: $e');
        Navigator.pushNamedAndRemoveUntil(
            context,
            (argument!['sellId'] == null) ? '/layout' : '/sale',
            ModalRoute.withName('/home'));
      }
    });
  }

  alertPending(BuildContext context) {
    AlertDialog alert = new AlertDialog(
      content: Text(AppLocalizations.of(context).translate('pending_message'),
          style: AppTheme.getTextStyle(themeData.textTheme.bodyText2,
              color: themeData.colorScheme.onBackground,
              fontWeight: 500,
              muted: true)),
      actions: <Widget>[
        TextButton(
            style: TextButton.styleFrom(
                primary: themeData.colorScheme.onPrimary,
                backgroundColor: themeData.colorScheme.primary),
            onPressed: () {
              Navigator.pop(context);
              if (!saleCreated) {
                onSubmit();
              }
            },
            child: Text(AppLocalizations.of(context).translate('ok'))),
        TextButton(
            style: TextButton.styleFrom(
                primary: themeData.colorScheme.primary,
                backgroundColor: themeData.colorScheme.onPrimary),
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text(AppLocalizations.of(context).translate('cancel')))
      ],
    );
    showDialog(
      barrierDismissible: true,
      context: context,
      builder: (BuildContext context) {
        return alert;
      },
    );
  }

  alertConfirm(BuildContext context, index) {
    AlertDialog alert = new AlertDialog(
      title: Icon(
        MdiIcons.alert,
        color: Colors.red,
        size: MySize.size50,
      ),
      content: Text(AppLocalizations.of(context).translate('are_you_sure'),
          textAlign: TextAlign.center,
          style: AppTheme.getTextStyle(themeData.textTheme.bodyText1,
              color: themeData.colorScheme.onBackground,
              fontWeight: 600,
              muted: true)),
      actions: <Widget>[
        TextButton(
            style: TextButton.styleFrom(
                primary: themeData.colorScheme.primary,
                backgroundColor: themeData.colorScheme.onPrimary),
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text(AppLocalizations.of(context).translate('cancel'))),
        TextButton(
            style: TextButton.styleFrom(
                backgroundColor: Colors.red, primary: themeData.colorScheme.onError),
            onPressed: () {
              Navigator.pop(context);
              if (sellId != null && payments[index]['id'] != null) {
                deletedPaymentId.add(payments[index]['id']);
              }
              payments.removeAt(index);
              calculateMultiPayment();
            },
            child: Text(AppLocalizations.of(context).translate('ok')))
      ],
    );
    showDialog(
      barrierDismissible: true,
      context: context,
      builder: (BuildContext context) {
        return alert;
      },
    );
  }
}