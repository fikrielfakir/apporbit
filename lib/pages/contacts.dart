import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api_end_points.dart';
import '../apis/api.dart';
import '../apis/contact.dart';
import '../helpers/AppTheme.dart';
import '../helpers/SizeConfig.dart';
import '../helpers/otherHelpers.dart';
import '../locale/MyLocalizations.dart';
import '../models/contact_model.dart';
import '../models/database.dart';
import '../models/offline_manager.dart';
import '../models/system.dart';
import '../pages/forms.dart';

class Contacts extends StatefulWidget {
  @override
  _ContactsState createState() => _ContactsState();
}

class _ContactsState extends State<Contacts> {
  final _formKey = GlobalKey<FormState>();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool isLoading = false, useOrderBy = false, orderByAsc = true;
  List<Map> customerList = [];
  ScrollController customerListController = ScrollController();
  var searchController = TextEditingController();
  String? fetchCustomers = Api().baseUrl + Api().apiUrl + "/contactapi?type=customer&per_page=10";
  String orderByColumn = 'name', orderByDirection = 'asc';
  Timer? _debounce;


  TextEditingController prefix = new TextEditingController(),
      firstName = new TextEditingController(),
      lastName = new TextEditingController(),
      mobile = new TextEditingController(),
      addressLine1 = new TextEditingController(),
      addressLine2 = new TextEditingController(),
      city = new TextEditingController(),
      refrige_num = new TextEditingController();

  static int themeType = 1;
  ThemeData themeData = AppTheme.getThemeFromThemeMode(themeType);
  CustomAppTheme customAppTheme = AppTheme.getCustomAppTheme(themeType);

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        sortContactList();
      });
    });
  }

  @override
  void initState() {
    super.initState();
    setCustomersList();
    customerListController.addListener(() {
      if (customerListController.position.pixels ==
          customerListController.position.maxScrollExtent) {
        setCustomersList();
      }
    });
    searchController.addListener(_onSearchChanged);
    Helper().syncCallLogs();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      endDrawer: _filterDrawer(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(MaterialPageRoute<Null>(
              builder: (BuildContext context) {
                return newCustomer();
              },
              fullscreenDialog: true));
        },
        child: Icon(MdiIcons.accountPlus),
        elevation: 2,
      ),
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: themeData.colorScheme.primary),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _refreshData,
          ),
          IconButton(
            icon: Icon(MdiIcons.filterVariant),
            onPressed: () {
              _scaffoldKey.currentState!.openEndDrawer();
            },
          )
        ],
        title: Text(AppLocalizations.of(context).translate('contacts'),
            style: AppTheme.getTextStyle(themeData.textTheme.headline6,
                fontWeight: 600)),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(60),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextFormField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context).translate('search_name_or_phone'),
                prefixIcon: Icon(MdiIcons.magnify),
                suffixIcon: searchController.text.isNotEmpty
                    ? IconButton(
                  icon: Icon(Icons.clear),
                  onPressed: () {
                    searchController.clear();
                    sortContactList();
                  },
                )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: themeData.colorScheme.background,
              ),
              onFieldSubmitted: (_) => sortContactList(),
            ),
          ),
        ),
      ),
      body: customerTab(customerList),
    );
  }
  // Refresh method to reload customer data
  void _refreshData() async {
    setState(() {
      isLoading = true;
    });

    try {
      setState(() {
        customerList.clear();
      });

      fetchCustomers = getUrl();
      await setCustomersList();

      Fluttertoast.showToast(
        msg: AppLocalizations.of(context).translate('refreshed_successfully'),
        backgroundColor: Colors.green,
        toastLength: Toast.LENGTH_SHORT,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: AppLocalizations.of(context).translate('refresh_failed'),
        backgroundColor: Colors.red,
        toastLength: Toast.LENGTH_SHORT,
      );
      print('Refresh error: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // Delete operation
  Future<void> _deleteContact(Map contact) async {
    if (!await Helper().checkConnectivity()) {
      Fluttertoast.showToast(
        msg: AppLocalizations.of(context).translate('check_connectivity'),
        backgroundColor: Colors.red,
        toastLength: Toast.LENGTH_LONG,
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final confirmDelete = await showDialog(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: Text(AppLocalizations.of(context).translate('confirm_delete')),
          content: Text(AppLocalizations.of(context).translate('confirm_delete_message')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(AppLocalizations.of(context).translate('cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                AppLocalizations.of(context).translate('delete'),
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      ) ?? false;

      if (!confirmDelete) {
        setState(() => isLoading = false);
        return;
      }

      final response = await CustomerApi().deleteContact(contact['id']);

      if (response['success'] == true) {
        await Contact().deleteContact(contact['id']);

        Fluttertoast.showToast(
          msg: AppLocalizations.of(context).translate('contact_deleted_successfully'),
          backgroundColor: Colors.green,
          toastLength: Toast.LENGTH_LONG,
        );

        await Future.delayed(Duration(milliseconds: 300));
        _refreshData();
      } else {
        Fluttertoast.showToast(
          msg: response['message'] ?? AppLocalizations.of(context).translate('failed_to_delete_contact'),
          backgroundColor: Colors.red,
          toastLength: Toast.LENGTH_LONG,
        );
      }
    } catch (e) {
      print('Error deleting contact: $e');
      Fluttertoast.showToast(
        msg: AppLocalizations.of(context).translate('error_deleting_contact'),
        backgroundColor: Colors.red,
        toastLength: Toast.LENGTH_LONG,
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // Contact Details View
  void _showContactDetails(Map contact) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (_, scrollController) {
              return SingleChildScrollView(
                controller: scrollController,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        margin: EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          AppLocalizations.of(context).translate('contact_details'),
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          children: [
                            Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(50),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(50),
                                onTap: () {
                                  Navigator.pop(context);
                                  _editContact(contact);
                                },
                                child: Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Icon(
                                    Icons.edit_outlined,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(50),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(50),
                                onTap: () => Navigator.pop(context),
                                child: Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Icon(
                                    Icons.close,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Divider(height: 1),
                    SizedBox(height: 24),
                    _buildPrimaryInfo(context, contact),
                    SizedBox(height: 32),
                    _buildSectionTitle(context, 'communication'),
                    SizedBox(height: 16),
                    _buildCommunicationInfo(context, contact),
                    SizedBox(height: 32),
                    _buildSectionTitle(context, 'business_address'),
                    SizedBox(height: 16),
                    _buildBusinessAndAddress(context, contact),
                    SizedBox(height: 32),
                    _buildSectionTitle(context, 'financial'),
                    SizedBox(height: 16),
                    _buildFinancialInfo(context, contact),
                    SizedBox(height: 40),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      AppLocalizations.of(context).translate(title.toLowerCase().replaceAll(' & ', '_').replaceAll(' ', '_')),
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Widget _buildPrimaryInfo(BuildContext context, Map contact) {
    final String name = contact['name'] ?? 'Unknown';
    final String businessName = contact['supplier_business_name'] ?? '';
    final String contactId = contact['contact_id'] ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                _getInitials(name),
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: 16),
        Center(
          child: Column(
            children: [
              Text(
                name,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              if (businessName.isNotEmpty) ...[
                SizedBox(height: 4),
                Text(
                  businessName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey.shade700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              SizedBox(height: 4),
              Text(
                '${AppLocalizations.of(context).translate('id')}: $contactId',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCommunicationInfo(BuildContext context, Map contact) {
    final String mobile = contact['mobile'] ?? '';
    final String alternate = contact['alternate_number'] ?? '';
    final String landline = contact['landline'] ?? '';
    final String email = contact['email'] ?? '';

    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (mobile.isNotEmpty)
              _buildContactItem(
                context,
                Icons.phone_android,
                AppLocalizations.of(context).translate('mobile'),
                mobile,
                onTap: () => _launchUrl('tel:$mobile'),
              ),
            if (alternate.isNotEmpty) ...[
              Divider(height: 24),
              _buildContactItem(
                context,
                Icons.phone,
                AppLocalizations.of(context).translate('alternate'),
                alternate,
                onTap: () => _launchUrl('tel:$alternate'),
              ),
            ],
            if (landline.isNotEmpty) ...[
              Divider(height: 24),
              _buildContactItem(
                context,
                Icons.phone_in_talk,
                AppLocalizations.of(context).translate('landline'),
                landline,
                onTap: () => _launchUrl('tel:$landline'),
              ),
            ],
            if (email.isNotEmpty) ...[
              Divider(height: 24),
              _buildContactItem(
                context,
                Icons.email,
                AppLocalizations.of(context).translate('email'),
                email,
                onTap: () => _launchUrl('mailto:$email'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBusinessAndAddress(BuildContext context, Map contact) {
    final String taxNumber = contact['tax_number'] ?? '';
    final String refrigeNum = contact['refrige_num'] ?? '';
    final List<dynamic> addressPartsDynamic = [
      contact['address_line_1'] ?? '',
      contact['address_line_2'] ?? '',
      contact['city'] ?? '',
    ].where((part) => part.isNotEmpty).toList();
    final List<String> addressParts = addressPartsDynamic.map((part) => part.toString()).toList();
    final String address = addressParts.join(', ');

    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (taxNumber.isNotEmpty)
              _buildContactItem(context, Icons.receipt_long, AppLocalizations.of(context).translate('tax_number'), taxNumber),
            if (refrigeNum.isNotEmpty) ...[
              if (taxNumber.isNotEmpty) Divider(height: 24),
              _buildContactItem(context, Icons.ac_unit, AppLocalizations.of(context).translate('refrigeration_number'), refrigeNum),
            ],
            if (address.isNotEmpty) ...[
              if (taxNumber.isNotEmpty || refrigeNum.isNotEmpty) Divider(height: 24),
              _buildContactItem(
                context,
                Icons.location_on,
                AppLocalizations.of(context).translate('address'),
                address,
                onTap: () => _launchUrl('https://maps.google.com/?q=$address'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialInfo(BuildContext context, Map contact) {
    final String creditLimit = contact['credit_limit']?.toString() ?? 'N/A';
    final String balance = contact['balance']?.toString() ?? '0.00';
    final bool hasBalance = balance != '0.00' && balance != 'N/A';
    final bool isNegative = hasBalance && double.tryParse(balance) != null && double.parse(balance) < 0;

    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildContactItem(context, Icons.credit_card, AppLocalizations.of(context).translate('credit_limit'), creditLimit),
            Divider(height: 24),
            _buildContactItem(
              context,
              isNegative ? Icons.arrow_downward : Icons.arrow_upward,
              AppLocalizations.of(context).translate('balance'),
              balance,
              valueColor: isNegative
                  ? Colors.red.shade700
                  : (hasBalance ? Colors.green.shade700 : null),
              valueWeight: FontWeight.bold,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactItem(
      BuildContext context,
      IconData icon,
      String label,
      String value, {
        Function()? onTap,
        Color? valueColor,
        FontWeight? valueWeight,
      }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: valueColor,
                      fontWeight: valueWeight,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: Colors.grey.shade400,
              ),
          ],
        ),
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final List<String> nameParts = name.trim().split(' ');
    if (nameParts.length > 1) {
      return '${nameParts.first[0]}${nameParts.last[0]}'.toUpperCase();
    } else {
      return name.substring(0, 1).toUpperCase();
    }
  }

  void _launchUrl(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    }
  }

  void _editContact(Map contact) {
    prefix.text = contact['prefix'] ?? '';
    firstName.text = contact['first_name'] ?? '';
    lastName.text = contact['last_name'] ?? '';
    mobile.text = contact['mobile'] ?? '';
    addressLine1.text = contact['address_line_1'] ?? '';
    addressLine2.text = contact['address_line_2'] ?? '';
    city.text = contact['city'] ?? '';
    refrige_num.text = contact['refrige_num'] ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: themeData.scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final mediaQuery = MediaQuery.of(context);
            final availableHeight = mediaQuery.size.height;
            final bottomPadding = mediaQuery.viewInsets.bottom;

            Widget _buildSectionHeader(BuildContext context, String title) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              );
            }

            return Container(
              height: availableHeight * 0.95,
              padding: EdgeInsets.only(bottom: bottomPadding),
              child: SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            AppLocalizations.of(context).translate('edit'),
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            semanticsLabel: AppLocalizations.of(context).translate('edit_contact_heading'),
                          ),
                          IconButton(
                            icon: Icon(Icons.close),
                            tooltip: AppLocalizations.of(context).translate('close'),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                    const Divider(),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: AutofillGroup(
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSectionHeader(context, AppLocalizations.of(context).translate('personal_info')),
                                _buildNameFields(themeData),
                                const SizedBox(height: 24),
                                _buildSectionHeader(context, AppLocalizations.of(context).translate('address')),
                                _buildAddressFields(themeData),
                                const SizedBox(height: 24),
                                _buildSectionHeader(context, AppLocalizations.of(context).translate('contact')),
                                _buildContactFields(themeData),
                                const SizedBox(height: 24),
                                _buildSectionHeader(context, AppLocalizations.of(context).translate('additional_info')),
                                _buildAdditionalFields(themeData),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () => _handleContactUpdate(contact, setState),
                              child: Text(
                                AppLocalizations.of(context).translate('update'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildNameFields(ThemeData themeData) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Container(
          width: 64,
          child: Center(
            child: Icon(
              MdiIcons.accountChildCircle,
              color: themeData.colorScheme.onBackground,
            ),
          ),
        ),
        Expanded(
          flex: 1,
          child: Container(
            margin: EdgeInsets.only(left: 16),
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 50,
                      child: TextFormField(
                        controller: prefix,
                        style: themeData.textTheme.subtitle2!.merge(
                            TextStyle(color: themeData.colorScheme.onBackground)
                        ),
                        decoration: InputDecoration(
                          hintText: AppLocalizations.of(context).translate('prefix'),
                          border: UnderlineInputBorder(
                            borderSide: BorderSide(
                                color: themeData.inputDecorationTheme.border!.borderSide.color),
                          ),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                                color: themeData.inputDecorationTheme.enabledBorder!.borderSide.color),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                                color: themeData.inputDecorationTheme.focusedBorder!.borderSide.color),
                          ),
                        ),
                        textCapitalization: TextCapitalization.sentences,
                      ),
                    ),
                    SizedBox(width: 4),
                    Expanded(
                      child: TextFormField(
                        controller: firstName,
                        validator: (value) {
                          if (value!.isEmpty) {
                            return AppLocalizations.of(context)
                                .translate('please_enter_your_name');
                          }
                          return null;
                        },
                        style: themeData.textTheme.subtitle2!.merge(
                            TextStyle(color: themeData.colorScheme.onBackground)
                        ),
                        decoration: InputDecoration(
                          hintText: AppLocalizations.of(context).translate('first_name'),
                          border: UnderlineInputBorder(
                            borderSide: BorderSide(
                                color: themeData.inputDecorationTheme.border!.borderSide.color),
                          ),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                                color: themeData.inputDecorationTheme.enabledBorder!.borderSide.color),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                                color: themeData.inputDecorationTheme.focusedBorder!.borderSide.color),
                          ),
                        ),
                        textCapitalization: TextCapitalization.sentences,
                      ),
                    )
                  ],
                ),
                SizedBox(height: 8),
                TextFormField(
                  controller: lastName,
                  style: themeData.textTheme.subtitle2!.merge(
                      TextStyle(color: themeData.colorScheme.onBackground)
                  ),
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context).translate('last_name'),
                    border: UnderlineInputBorder(
                      borderSide: BorderSide(
                          color: themeData.inputDecorationTheme.border!.borderSide.color),
                    ),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(
                          color: themeData.inputDecorationTheme.enabledBorder!.borderSide.color),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(
                          color: themeData.inputDecorationTheme.focusedBorder!.borderSide.color),
                    ),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
              ],
            ),
          ),
        )
      ],
    );
  }

  Widget _buildAddressFields(ThemeData themeData) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Container(
              width: 64,
              child: Center(
                child: Icon(
                  MdiIcons.homeCityOutline,
                  color: themeData.colorScheme.onBackground,
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Container(
                margin: EdgeInsets.only(left: 16),
                child: Column(
                  children: <Widget>[
                    TextFormField(
                      controller: addressLine1,
                      style: themeData.textTheme.subtitle2!.merge(
                          TextStyle(color: themeData.colorScheme.onBackground)
                      ),
                      decoration: InputDecoration(
                        hintText: AppLocalizations.of(context).translate('address_line_1'),
                        border: UnderlineInputBorder(
                          borderSide: BorderSide(
                              color: themeData.inputDecorationTheme.border!.borderSide.color),
                        ),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                              color: themeData.inputDecorationTheme.enabledBorder!.borderSide.color),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                              color: themeData.inputDecorationTheme.focusedBorder!.borderSide.color),
                        ),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    SizedBox(height: 8),
                  ],
                ),
              ),
            )
          ],
        ),
        SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
        ),
      ],
    );
  }

  Widget _buildContactFields(ThemeData themeData) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Container(
          width: 64,
          child: Center(
            child: Icon(
              MdiIcons.phoneOutline,
              color: themeData.colorScheme.onBackground,
            ),
          ),
        ),
        Expanded(
          flex: 1,
          child: Container(
            margin: EdgeInsets.only(left: 16),
            child: Column(
              children: <Widget>[
                TextFormField(
                  controller: mobile,
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value!.isEmpty) {
                      return AppLocalizations.of(context)
                          .translate('please_enter_your_number');
                    }
                    return null;
                  },
                  style: themeData.textTheme.subtitle2!.merge(
                      TextStyle(color: themeData.colorScheme.onBackground)
                  ),
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context).translate('phone'),
                    border: UnderlineInputBorder(
                      borderSide: BorderSide(
                          color: themeData.inputDecorationTheme.border!.borderSide.color),
                    ),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(
                          color: themeData.inputDecorationTheme.enabledBorder!.borderSide.color),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(
                          color: themeData.inputDecorationTheme.focusedBorder!.borderSide.color),
                    ),
                  ),
                ),
              ],
            ),
          ),
        )
      ],
    );
  }

  Widget _buildAdditionalFields(ThemeData themeData) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Container(
              width: 64,
              child: Center(
                child: Icon(
                  Icons.ac_unit,
                  color: themeData.colorScheme.onBackground,
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Container(
                margin: EdgeInsets.only(left: 16),
                child: Column(
                  children: <Widget>[
                    SizedBox(height: 8),
                    TextFormField(
                      controller: refrige_num,
                      style: themeData.textTheme.subtitle2!.merge(
                          TextStyle(color: themeData.colorScheme.onBackground)
                      ),
                      decoration: InputDecoration(
                        hintText: AppLocalizations.of(context).translate('refrige_num'),
                        border: UnderlineInputBorder(
                          borderSide: BorderSide(
                              color: themeData.inputDecorationTheme.border!.borderSide.color),
                        ),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                              color: themeData.inputDecorationTheme.enabledBorder!.borderSide.color),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                              color: themeData.inputDecorationTheme.focusedBorder!.borderSide.color),
                        ),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    SizedBox(height: 8),
                  ],
                ),
              ),
            )
          ],
        ),
      ],
    );
  }

  Future<void> _handleContactUpdate(Map contact, StateSetter setModalState) async {
    if (_formKey.currentState!.validate()) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Center(child: CircularProgressIndicator());
        },
      );

      try {
        if (!await Helper().checkConnectivity()) {
          Navigator.pop(context);
          Fluttertoast.showToast(
            msg: AppLocalizations.of(context).translate('check_connectivity'),
            backgroundColor: Colors.red,
            toastLength: Toast.LENGTH_LONG,
          );
          return;
        }

        Map updatedContact = {
          'type': 'customer',
          'prefix': prefix.text,
          'first_name': firstName.text,
          'last_name': lastName.text,
          'mobile': mobile.text,
          'address_line_1': addressLine1.text,
          'address_line_2': addressLine2.text,
          'city': city.text,
          'refrige_num': refrige_num.text
        };

        final response = await CustomerApi().update(updatedContact, contact['id']);

        Navigator.pop(context);

        if (response != null && response['data'] != null) {
          final index = customerList.indexWhere((c) => c['id'] == contact['id']);
          if (index != -1) {
            setState(() {
              customerList[index] = response['data'];
            });
          }

          await Contact().updateContact(Contact().contactModel(response['data']));

          Navigator.pop(context);
          _showContactDetails(response['data']);

          Fluttertoast.showToast(
            msg: AppLocalizations.of(context).translate('contact_updated_successfully'),
            backgroundColor: Colors.green,
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
          );
        } else {
          Fluttertoast.showToast(
            msg: response?['message'] ?? AppLocalizations.of(context).translate('update_failed'),
            backgroundColor: Colors.red,
            toastLength: Toast.LENGTH_LONG,
            gravity: ToastGravity.BOTTOM,
          );
        }
      } catch (e) {
        Navigator.pop(context);
        Fluttertoast.showToast(
          msg: AppLocalizations.of(context).translate('error_occurred'),
          backgroundColor: Colors.red,
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
        );
        print('Error updating contact: $e');
      }
    }
  }

  Widget contactBlock(contactDetails) {
    return InkWell(
      onTap: () => _showContactDetails(contactDetails),
      child: Container(
        margin: EdgeInsets.only(bottom: MySize.size8!),
        padding: EdgeInsets.all(MySize.size8!),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(MySize.size8!)),
          color: customAppTheme.bgLayer1,
          border: Border.all(color: customAppTheme.bgLayer4, width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Visibility(
              visible: (contactDetails['supplier_business_name'].toString() != 'null'),
              child: Text(
                '${contactDetails['supplier_business_name']}',
                style: AppTheme.getTextStyle(
                  themeData.textTheme.bodyText1,
                  fontWeight: 600,
                  color: themeData.colorScheme.onBackground,
                ),
              ),
            ),
            Visibility(
              visible: (contactDetails['name'].toString() != 'null' &&
                  contactDetails['name'].toString().trim() != ''),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${AppLocalizations.of(context).translate('customer')} : ",
                    style: AppTheme.getTextStyle(
                      themeData.textTheme.bodyText1,
                      fontWeight: 600,
                      color: themeData.colorScheme.onBackground,
                    ),
                  ),
                  Flexible(
                    fit: FlexFit.loose,
                    child: Text(
                      '${contactDetails['name']}',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.getTextStyle(
                        themeData.textTheme.bodyText2,
                        fontWeight: 500,
                        color: themeData.colorScheme.onBackground,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Helper().callDropdown(
                  context,
                  contactDetails['mobile'],
                  [
                    contactDetails['mobile'] ?? ''
                  ],
                  type: 'call',
                ),
                IconButton(
                  icon: Icon(Icons.edit, size: 24, color: Colors.green),
                  onPressed: () => _editContact(contactDetails),
                ),
                IconButton(
                  icon: Icon(Icons.remove_red_eye_sharp, size: 24, color: Colors.blue),
                  onPressed: () => _showContactDetails(contactDetails),
                ),
                IconButton(
                  icon: Icon(Icons.delete, size: 24, color: Colors.red),
                  onPressed: () => _deleteContact(contactDetails),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  // Retrieve customers list from api or cache
  setCustomersList() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Check connectivity and offline mode
      bool hasConnectivity = await Helper().checkConnectivity();
      bool isOfflineMode = await OfflineManager().isOfflineMode;

      if (!hasConnectivity || isOfflineMode) {
        await _loadContactsFromCache();
        return;
      }

      final dio = Dio();
      var token = await System().getToken();
      dio.options.headers['content-Type'] = 'application/json';
      dio.options.headers["Authorization"] = "Bearer $token";
      final response = await dio.get(fetchCustomers!);

      if (response.statusCode == 200) {
        List<dynamic> customers = response.data['data'] ?? [];
        Map links = response.data['links'] ?? {};
        setState(() {
          customerList.addAll(customers.cast<Map<dynamic, dynamic>>());
          isLoading = (links['next'] != null) ? true : false;
          fetchCustomers = links['next'];
        });
        // Cache data for offline access
        await _cacheContacts(customers);
      } else {
        throw Exception('Failed to load customers');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      Fluttertoast.showToast(
        msg: AppLocalizations.of(context).translate('error_loading_contacts'),
        backgroundColor: Colors.red,
        toastLength: Toast.LENGTH_LONG,
      );
      print('Error fetching customers: $e');
      // Fallback to cache if API fails
      await _loadContactsFromCache();
    }
  }

  // Load contacts from local cache
  _loadContactsFromCache() async {
    try {
      final cachedContacts = await Contact().getAllContacts();
      if (cachedContacts.isNotEmpty) {
        setState(() {
          customerList = cachedContacts;
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
        Fluttertoast.showToast(
          msg: AppLocalizations.of(context).translate('no_contacts_found_offline'),
          backgroundColor: Colors.orange,
          toastLength: Toast.LENGTH_SHORT,
        );
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      print('Error loading contacts from cache: $e');
      Fluttertoast.showToast(
        msg: AppLocalizations.of(context).translate('error_loading_cached_contacts'),
        backgroundColor: Colors.red,
        toastLength: Toast.LENGTH_LONG,
      );
    }
  }

  // Cache contacts data
  _cacheContacts(List<dynamic> customers) async {
    try {
      for (var customerData in customers) {
        await Contact().insertContact(Contact().contactModel(customerData));
      }
    } catch (e) {
      print('Error caching contacts: $e');
    }
  }

  // Customer widget
  Widget customerTab(customers) {
    return Stack(
      children: [
        if (customers.length > 0)
          ListView.builder(
              controller: customerListController,
              padding: EdgeInsets.all(MySize.size12!),
              shrinkWrap: true,
              itemCount: customers.length + 1,
              itemBuilder: (context, index) {
                if (index == customers.length) {
                  return (isLoading) ? _buildProgressIndicator() : Container();
                } else {
                  return contactBlock(customers[index]);
                }
              })
        else
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  MdiIcons.accountSearch,
                  size: 48,
                  color: themeData.colorScheme.onBackground.withOpacity(0.3),
                ),
                SizedBox(height: 16),
                Text(
                  searchController.text.isNotEmpty
                      ? AppLocalizations.of(context).translate('no_contacts_found')
                      : AppLocalizations.of(context).translate('no_contacts'),
                  style: AppTheme.getTextStyle(
                    themeData.textTheme.subtitle1,
                    fontWeight: 600,
                    color: themeData.colorScheme.onBackground.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        if (isLoading && customers.isEmpty)
          Center(child: CircularProgressIndicator()),
      ],
    );
  }

// Updated filter drawer with improved design
  Widget _filterDrawer() {
    return SafeArea(
      child: Container(
        padding: EdgeInsets.all(16),
        width: MediaQuery.of(context).size.width * 0.85,
        color: themeData.scaffoldBackgroundColor,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppLocalizations.of(context).translate('filter_contacts'),
                  style: themeData.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            SizedBox(height: 16),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context).translate('sort_by'),
                      style: themeData.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: themeData.colorScheme.primary,
                      ),
                    ),
                    SizedBox(height: 12),
                    SwitchListTile(
                      title: Text(
                        AppLocalizations.of(context).translate('enable_sorting'),
                        style: themeData.textTheme.bodyLarge,
                      ),
                      value: useOrderBy,
                      activeColor: themeData.colorScheme.primary,
                      onChanged: (value) {
                        setState(() {
                          useOrderBy = value;
                          sortContactList();
                        });
                      },
                    ),
                    if (useOrderBy) ...[
                      SizedBox(height: 16),
                      Text(
                        AppLocalizations.of(context).translate('sort_field'),
                        style: themeData.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      RadioListTile(
                        title: Text(AppLocalizations.of(context).translate('name')),
                        value: 'name',
                        groupValue: orderByColumn,
                        activeColor: themeData.colorScheme.primary,
                        onChanged: (value) {
                          setState(() {
                            orderByColumn = value.toString();
                            sortContactList();
                          });
                        },
                      ),
                      RadioListTile(
                        title: Text(AppLocalizations.of(context).translate('business_name')),
                        value: 'supplier_business_name',
                        groupValue: orderByColumn,
                        activeColor: themeData.colorScheme.primary,
                        onChanged: (value) {
                          setState(() {
                            orderByColumn = value.toString();
                            sortContactList();
                          });
                        },
                      ),
                      SizedBox(height: 16),
                      Text(
                        AppLocalizations.of(context).translate('sort_direction'),
                        style: themeData.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      RadioListTile(
                        title: Text(AppLocalizations.of(context).translate('ascending')),
                        value: true,
                        groupValue: orderByAsc,
                        activeColor: themeData.colorScheme.primary,
                        onChanged: (value) {
                          setState(() {
                            orderByAsc = value as bool;
                            orderByDirection = orderByAsc ? 'asc' : 'desc';
                            sortContactList();
                          });
                        },
                      ),
                      RadioListTile(
                        title: Text(AppLocalizations.of(context).translate('descending')),
                        value: false,
                        groupValue: orderByAsc,
                        activeColor: themeData.colorScheme.primary,
                        onChanged: (value) {
                          setState(() {
                            orderByAsc = value as bool;
                            orderByDirection = orderByAsc ? 'asc' : 'desc';
                            sortContactList();
                          });
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Spacer(),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        useOrderBy = false;
                        orderByColumn = 'name';
                        orderByAsc = true;
                        orderByDirection = 'asc';
                        searchController.clear();
                        sortContactList();
                      });
                      Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: themeData.colorScheme.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      AppLocalizations.of(context).translate('reset_filters'),
                      style: TextStyle(
                        color: themeData.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      sortContactList();
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      AppLocalizations.of(context).translate('apply_filters'),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  // Filter list
  // Updated sort and URL methods
  sortContactList() {
    setState(() {
      customerList = [];
      fetchCustomers = getUrl();
    });
    setCustomersList();
  }

  String getUrl({String? perPage = '10'}) {
    String url = Api().baseUrl + Api().apiUrl + '/contactapi?';
    Map<String, dynamic> params = {'type': 'customer'};

    if (searchController.text.isNotEmpty) {
      params['name'] = searchController.text;
      params['mobile'] = searchController.text;
    }

    if (useOrderBy) {
      params['order_by'] = orderByColumn;
      params['direction'] = orderByDirection;
    }

    if (perPage != null) {
      params['per_page'] = perPage;
    }

    String queryString = Uri(queryParameters: params).query;
    return url + queryString;
  }

  Widget newCustomer() {
    final controllers = {
      'prefix': TextEditingController(),
      'firstName': TextEditingController(),
      'lastName': TextEditingController(),
      'mobile': TextEditingController(),
      'addressLine1': TextEditingController(),
      'addressLine2': TextEditingController(),
      'city': TextEditingController(),
      'refrige_num': TextEditingController()
    };

    final _formKey = GlobalKey<FormState>();
    bool _isSubmitting = false;

    void _clearAllFields() {
      controllers.forEach((_, controller) => controller.clear());
    }

    Future<void> _addCustomer() async {
      if (!_formKey.currentState!.validate() || _isSubmitting) return;

      setState(() => _isSubmitting = true);
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      try {
        final customerData = {
          'first_name': controllers['firstName']!.text.trim(),
          'last_name': controllers['lastName']!.text.trim(),
          'name': '${controllers['firstName']!.text.trim()} ${controllers['lastName']!.text.trim()}'.trim(),
          'mobile': controllers['mobile']!.text.trim(),
          'address_line_1': controllers['addressLine1']!.text.trim(),
          'city': controllers['city']!.text.trim(),
          'refrige_num': controllers['refrige_num']!.text.trim(),
          'type': 'customer',
          if (controllers['prefix']!.text.isNotEmpty) 'prefix': controllers['prefix']!.text.trim(),
          if (controllers['addressLine2']!.text.isNotEmpty) 'address_line_2': controllers['addressLine2']!.text.trim(),
        };

        final db = await DbProvider.db.database;
        final localId = await db.insert('contact', customerData);

        if (localId <= 0) throw Exception('Local database insertion failed');

        try {
          final apiResponse = await CustomerApi().add(customerData);
          if (apiResponse?['data'] != null) {
            await Contact().insertContact(Contact().contactModel(apiResponse['data']));
          }
        } catch (apiError) {
          debugPrint('API sync error: $apiError');
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).translate('contact_added_successfully')),
            backgroundColor: Colors.green,
          ),
        );

        _clearAllFields();
        Navigator.pop(context);
      } catch (e) {
        debugPrint('Contact addition error: $e');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppLocalizations.of(context).translate('error_occurred')}: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        if (mounted) {
          setState(() => _isSubmitting = false);
          Navigator.pop(context);
        }
      }
    }

    @override
    void dispose() {
      searchController.removeListener(_onSearchChanged);
      searchController.dispose();
      _debounce?.cancel();
      super.dispose();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context).translate('create_contact'),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            _clearAllFields();
            Navigator.pop(context);
          },
          tooltip: AppLocalizations.of(context).translate('back'),
        ),
        elevation: 0.5,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(context, 'personal_info'),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 70,
                            margin: const EdgeInsets.only(right: 12),
                            child: _buildTextField(
                              controller: controllers['prefix']!,
                              hintText: 'prefix',
                              labelText: 'prefix',
                              icon: MdiIcons.accountCircleOutline,
                            ),
                          ),
                          Expanded(
                            child: _buildTextField(
                              controller: controllers['firstName']!,
                              hintText: 'first_name',
                              labelText: 'first_name',
                              isRequired: true,
                              validator: (value) => value?.isEmpty ?? true
                                  ? AppLocalizations.of(context).translate('please_enter_your_name')
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: controllers['lastName']!,
                        hintText: 'last_name',
                        labelText: 'last_name',
                        isRequired: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return AppLocalizations.of(context).translate('last_name_required');
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      _buildSectionHeader(context, 'contact'),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: controllers['mobile']!,
                        hintText: 'phone',
                        labelText: 'phone',
                        icon: MdiIcons.phoneOutline,
                        keyboardType: TextInputType.phone,
                        isRequired: true,
                        validator: (value) => value?.isEmpty ?? true
                            ? AppLocalizations.of(context).translate('please_enter_your_number')
                            : null,
                        autofillHints: [AutofillHints.telephoneNumber],
                      ),
                      const SizedBox(height: 24),
                      _buildSectionHeader(context, 'address'),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: controllers['addressLine1']!,
                        hintText: 'address_line_1',
                        labelText: 'address_line_1',
                        icon: MdiIcons.mapMarkerOutline,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: controllers['city']!,
                        hintText: 'city',
                        labelText: 'city',
                        icon: MdiIcons.homeCityOutline,
                        autofillHints: [AutofillHints.addressCity],
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: controllers['refrige_num']!,
                        hintText: 'refrige_num',
                        labelText: 'refrige_num',
                        icon: Icons.ac_unit,
                        autofillHints: [AutofillHints.addressCity],
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      offset: const Offset(0, -2),
                      blurRadius: 4,
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _isSubmitting ? null : _addCustomer,
                  child: Text(
                    AppLocalizations.of(context).translate('add_to_contact').toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String titleKey) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        AppLocalizations.of(context).translate(titleKey),
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required String labelText,
    IconData? icon,
    bool isRequired = false,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    List<String>? autofillHints,
  }) {
    return Container(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: keyboardType,
        textCapitalization: TextCapitalization.sentences,
        autofillHints: autofillHints,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
        ),
        decoration: InputDecoration(
          labelText: AppLocalizations.of(context).translate(labelText) + (isRequired ? ' *' : ''),
          hintText: AppLocalizations.of(context).translate(hintText),
          prefixIcon: icon != null ? Icon(icon) : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.7),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.primary,
              width: 2,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface,
        ),
      ),
    );
  }

  void _saveContact(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Center(
          child: Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(AppLocalizations.of(context).translate('saving_contact')),
                ],
              ),
            ),
          ),
        );
      },
    );

    try {
      if (!await Helper().checkConnectivity()) {
        Navigator.pop(context);
        _showErrorToast('check_connectivity');
        return;
      }

      if (_formKey.currentState!.validate()) {
        Map newCustomer = {
          'type': 'customer',
          'prefix': prefix.text,
          'first_name': firstName.text,
          'last_name': lastName.text,
          'mobile': mobile.text,
          'address_line_1': addressLine1.text,
          'address_line_2': addressLine2.text,
          'city': city.text,
          'refrige_num': refrige_num.text,
        };

        final response = await CustomerApi().add(newCustomer);
        Navigator.pop(context);

        if (response['data'] != null) {
          await Contact().insertContact(Contact().contactModel(response['data']));
          _showSuccessToast('contact_added_successfully');
          _formKey.currentState!.reset();
          Navigator.pop(context);
        } else {
          _showErrorToast(response['message'] ?? 'error_adding_contact');
        }
      } else {
        Navigator.pop(context);
      }
    } catch (e) {
      Navigator.pop(context);
      _showErrorToast('error_occurred');
      print('Error adding contact: $e');
    }
  }

  void _showErrorToast(String messageKey) {
    Fluttertoast.showToast(
      msg: AppLocalizations.of(context).translate(messageKey),
      backgroundColor: Colors.red.shade700,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 3,
    );
  }

  void _showSuccessToast(String messageKey) {
    Fluttertoast.showToast(
      msg: AppLocalizations.of(context).translate(messageKey),
      backgroundColor: Colors.green.shade700,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 2,
    );
  }

  Widget _buildProgressIndicator() {
    return new Padding(
      padding: const EdgeInsets.all(8.0),
      child: new Center(
        child: FutureBuilder<bool>(
            future: Helper().checkConnectivity(),
            builder: (context, AsyncSnapshot<bool> snapshot) {
              if (snapshot.data == false) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      AppLocalizations.of(context)
                          .translate('check_connectivity'),
                      style: AppTheme.getTextStyle(
                          themeData.textTheme.subtitle1,
                          fontWeight: 700,
                          letterSpacing: -0.2),
                    ),
                    Icon(
                      Icons.error_outline,
                      color: themeData.colorScheme.onBackground,
                    )
                  ],
                );
              } else {
                return CircularProgressIndicator();
              }
            }),
      ),
    );
  }
}