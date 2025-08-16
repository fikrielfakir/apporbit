// import 'package:call_log/call_log.dart';
import 'package:flutter/material.dart';
import 'package:pos_final/config.dart';

import '../helpers/AppTheme.dart';
import '../helpers/SizeConfig.dart';
import 'database.dart';

class FollowUpModel {
  var createFollowUpMap;
  var followUpMap;
  static int themeType = 1;
  ThemeData themeData = AppTheme.getThemeFromThemeMode(themeType);
  CustomAppTheme customAppTheme = AppTheme.getCustomAppTheme(themeType);

  followUpForm(customerDetail) {
    followUpMap = {
      'id': customerDetail['contact_id'],
      'followUpId': customerDetail['id'],
      'name': '${customerDetail['customer']['name']}',
      'mobile': '${customerDetail['customer']['mobile']}',
      'landline': '${customerDetail['customer']['landline']}',
      'alternate_number': '${customerDetail['customer']['alternate_number']}',
      'title': '${customerDetail['title']}',
      'status': '${customerDetail['status']}',
      if (customerDetail['followup_category'] != null)
        'followup_category': {
          'id': int.parse(customerDetail['followup_category']['id'].toString()),
          'name': customerDetail['followup_category']['name']
        },
      'schedule_type': '${customerDetail['schedule_type']}',
      'start_datetime': '${customerDetail['start_datetime']}',
      'end_datetime': '${customerDetail['end_datetime']}',
      'description': customerDetail['description'] ?? ''
    };
    return followUpMap;
  }

  submitFollowUp(
      {id,
        contactId,
        title,
        scheduleType,
        status,
        followUpCategoryId,
        startDate,
        endDate,
        description,
        duration}) {
    createFollowUpMap = {
      'title': title,
      'contact_id': contactId,
      'schedule_type': scheduleType,
      'user_id': [Config.userId],
      'status': status,
      'followup_category_id': followUpCategoryId,
      'start_datetime': '$startDate',
      'end_datetime': '$endDate',
      'description': '$description',
      'followup_additional_info': (duration != null && scheduleType == 'call')
          ? {'call duration': '$duration'}
          : ''
    };
    return createFollowUpMap;
  }

  // Future<CallLogEntry> getLogs(number) async {int from = DateTime.now().subtract(Duration(hours: 8)).millisecondsSinceEpoch;String numberQuery = '%${number.replaceAll(RegExp("[^0-9]"), "")}';Iterable<CallLogEntry> entries = await CallLog.query(number: numberQuery, dateFrom: from);return (entries.isNotEmpty) ? entries.first : null;}

  //calling widget
  Widget callCustomer() {
    return Container(
      margin: EdgeInsets.only(left: MySize.size8!),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(MySize.size8!)),
        boxShadow: [
          BoxShadow(
            color: themeData.cardTheme.shadowColor!.withAlpha(48),
            blurRadius: 3,
            offset: Offset(0, 1),
          )
        ],
      ),
      padding: EdgeInsets.all(MySize.size4!),
      child: Icon(
        Icons.call,
        color: themeData.colorScheme.background,
      ),
    );
  }
}

class Contact {
  late DbProvider dbProvider;

  Contact() {
    dbProvider = new DbProvider();
  }

  Map<String, dynamic> contactModel(element) {
    Map<String, dynamic> customer = {
      'id': element['id'],
      'name': element['name'],
      'supplier_business_name': element['supplier_business_name'],
      'prefix': element['prefix'],
      'first_name': element['first_name'],
      'middle_name': element['middle_name'],
      'last_name': element['last_name'],
      'email': element['email'],
      'contact_id': element['contact_id'],
      'contact_status': element['contact_status'],
      'tax_number': element['tax_number'],
      'city': element['city'],
      'state': element['state'],
      'refrige_num': element['refrige_num'],
      'address_line_1': element['address_line_1'],
      'address_line_2': element['address_line_2'],
      'zip_code': element['zip_code'],
      'dob': element['dob'],
      'mobile': element['mobile'],
      'landline': element['landline'],
      'alternate_number': element['alternate_number'],
      'pay_term_number': element['pay_term_number'],
      'pay_term_type': element['pay_term_type'],
      'credit_limit': element['credit_limit'],
      'created_by': element['created_by'],
      'balance': element['balance'],
      'total_rp': element['total_rp'],
      'total_rp_used': element['total_rp_used'],
      'total_rp_expired': element['total_rp_expired'],
      'is_default': element['is_default'],
      'shipping_address': element['shipping_address'],
      'position': element['position'],
      'customer_group_id': element['customer_group_id'],
      'crm_source': element['crm_source'],
      'crm_life_stage': element['crm_life_stage'],
      'custom_field1': element['custom_field1'],
      'custom_field2': element['custom_field2'],
      'custom_field3': element['custom_field3'],
      'custom_field4': element['custom_field4'],
      'deleted_at': element['deleted_at'],
      'created_at': element['created_at'],
      'updated_at': element['updated_at'],
    };
    return customer;
  }

  //save contact
  insertContact(customer) async {
    final db = await dbProvider.database;
    var response = await db.insert('contact', customer);
    return response;
  }

  //get customer name by contact_id
  getCustomerDetailById(id) async {
    final db = await dbProvider.database;
    List response =
    await db.query('contact', where: 'id = ?', whereArgs: ['$id']);
    var customerDetail = (response.length > 0) ? response[0] : null;
    return customerDetail;
  }

  //get customer name by contact_id
  Future<List<Map<String, dynamic>>> get({bool? all}) async {
    final db = await dbProvider.database;
    if (all == true) {
      List<Map<String, dynamic>> customers = await db.query('contact');
      return customers;
    } else {
      List<Map<String, dynamic>> customers = await db.query('contact',
          columns: ['id', 'name', 'mobile'], orderBy: 'name ASC');
      return customers;
    }
  }

  Future<List<Map<String, dynamic>>> getAllContacts() async {
    final db = await DbProvider.db.database;
    List<Map<String, dynamic>> result = await db.query("contact");
    return result.map((row) => Map<String, dynamic>.from(row)).toList();
  }
  //empty contact table
  emptyContact() async {
    final db = await dbProvider.database;
    var response = await db.delete('contact');
    return response;
  }
  updateContact(customer) async {
    final db = await dbProvider.database;
    var response = await db.update(
      'contact',
      customer,
      where: 'id = ?',
      whereArgs: [customer['id']],
    );
    return response;
  }

  deleteContact(id) async {
    final db = await dbProvider.database;
    var response = await db.delete('contact', where: 'id = ?', whereArgs: [id]);
    return response;
  }
}