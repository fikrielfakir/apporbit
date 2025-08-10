import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import '../apis/sell.dart';
import '../helpers/otherHelpers.dart';
import '../locale/MyLocalizations.dart';
import '../models/contact_model.dart';
import '../models/sellDatabase.dart';
import '../models/system.dart';

class SellReturn extends StatefulWidget {
final int? saleId;
SellReturn({this.saleId});

@override
_SellReturnState createState() => _SellReturnState();
}

class _SellReturnState extends State<SellReturn> {
List<Map> sellList = [];
List<Map> filteredSellList = [];
Map? selectedSell;
double totalReturnAmount = 0.0;
String symbol = '';
TextEditingController returnDateController = TextEditingController();
TextEditingController returnNoteController = TextEditingController();
bool isLoading = false;
TextEditingController searchController = TextEditingController();
bool showSellList = true;
List<Map<String, dynamic>> selectedProducts = [];

@override
void initState() {
super.initState();
_initializeData();
searchController.addListener(() => filterSells(searchController.text));
}

Future<void> _initializeData() async {
setState(() => isLoading = true);
await getInitDetails();

if (widget.saleId != null) {
await fetchSellById(widget.saleId!);
setState(() => showSellList = false);
} else {
await fetchSells();
}

setState(() => isLoading = false);
}

Future<void> getInitDetails() async {
var details = await Helper().getFormattedBusinessDetails();
setState(() => symbol = details['symbol']);
}

Future<void> fetchSellById(int saleId) async {
try {
var sell = await SellDatabase().getSellById(saleId);
var customer = await Contact().getCustomerDetailById(sell['contact_id']);
var location = await Helper().getLocationNameById(sell['location_id']);

setState(() {
selectedSell = {
'id': sell['id'],
'invoice_no': sell['invoice_no'],
'customer_name': customer['name'],
'location_name': location,
'invoice_amount': sell['invoice_amount'],
'transaction_date': sell['transaction_date'],
};
fetchProductsForSell(sell['id']); // Ensure this triggers product loading
});
} catch (e) {
Fluttertoast.showToast(msg: 'Failed to load sale details: $e');
}
}

Future<void> fetchSells() async {
List<Map> tempSellList = [];
var sells = await SellDatabase().getSells(all: true);

for (var element in sells) {
var customer = await Contact().getCustomerDetailById(element['contact_id']);
var location = await Helper().getLocationNameById(element['location_id']);

tempSellList.add({
'id': element['id'],
'invoice_no': element['invoice_no'],
'customer_name': customer['name'],
'location_name': location,
'invoice_amount': element['invoice_amount'],
'transaction_date': element['transaction_date'],
});
}

setState(() {
sellList = tempSellList;
filteredSellList = List.from(tempSellList);
});
}

Future<void> fetchProductsForSell(int sellId) async {
  setState(() => isLoading = true);
  try {
    // Replace getProductsBySellId with get method
    List products = await SellDatabase().get(sellId: sellId);

    List<Map<String, dynamic>> formattedProducts = [];

    for (var product in products) {
      // Convert to proper format
      Map<String, dynamic> formattedProduct = {};
      product.forEach((key, value) {
        formattedProduct[key.toString()] = value;
      });
      formattedProduct['returnQuantity'] = 0.0; // Initialize return quantity to 0
      formattedProducts.add(formattedProduct);
    }

    setState(() {
      selectedProducts = formattedProducts;
      isLoading = false;
      showSellList = false; // Hide the sell list when products are fetched
    });
  } catch (e) {
    setState(() => isLoading = false);
    Fluttertoast.showToast(msg: 'Failed to load products: $e');
    print('Failed to load products: $e');
  }
}

void filterSells(String query) {
setState(() {
filteredSellList = sellList.where((sell) {
return sell['invoice_no'].toString().contains(query) ||
sell['customer_name'].toLowerCase().contains(query.toLowerCase());
}).toList();
});
}

void goBackToList() {
setState(() {
showSellList = true;
selectedSell = null;
selectedProducts = [];
});
}

@override
Widget build(BuildContext context) {
return Scaffold(
appBar: AppBar(
title: Text("إرجاع المبيعات"),
actions: [
if (!showSellList && widget.saleId == null)
IconButton(
icon: Icon(Icons.arrow_back),
onPressed: goBackToList,
),
],
),
body: isLoading
? Center(child: CircularProgressIndicator())
    : Column(
children: [
if (showSellList && widget.saleId == null) ...[
Padding(
padding: EdgeInsets.all(8.0),
child: TextField(
controller: searchController,
decoration: InputDecoration(
labelText: 'بحث في الفواتير أو العملاء',
prefixIcon: Icon(Icons.search),
border: OutlineInputBorder(),
),
),
),
Padding(
padding: EdgeInsets.symmetric(horizontal: 16.0),
child: Row(
mainAxisAlignment: MainAxisAlignment.spaceBetween,
children: [
Text(
'عدد المبيعات: ${filteredSellList.length}',
style: TextStyle(fontWeight: FontWeight.bold),
),
],
),
),
Expanded(
child: filteredSellList.isEmpty
? Center(child: Text('لا توجد مبيعات للعرض'))
    : ListView.builder(
itemCount: filteredSellList.length,
itemBuilder: (context, index) {
var sell = filteredSellList[index];
return Card(
margin: EdgeInsets.symmetric(
horizontal: 8.0, vertical: 4.0),
child: ListTile(
contentPadding: EdgeInsets.all(8.0),
title: Row(
children: [
Text(
'رقم الفاتورة: ${sell['invoice_no']}',
style: TextStyle(
fontWeight: FontWeight.bold),
),
Spacer(),
Container(
padding: EdgeInsets.symmetric(
horizontal: 8.0, vertical: 4.0),
decoration: BoxDecoration(
color: Colors.blue[100],
borderRadius:
BorderRadius.circular(4.0),
),
child: Text(
'$symbol ${sell['invoice_amount']}',
style: TextStyle(
fontWeight: FontWeight.bold),
),
),
],
),
subtitle: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
SizedBox(height: 8.0),
Row(
children: [
Icon(Icons.person, size: 16),
SizedBox(width: 4.0),
Text('العميل: ${sell['customer_name']}'),
],
),
SizedBox(height: 4.0),
Row(
children: [
Icon(Icons.location_on, size: 16),
SizedBox(width: 4.0),
Text('الموقع: ${sell['location_name']}'),
],
),
SizedBox(height: 4.0),
Row(
children: [
Icon(Icons.calendar_today, size: 16),
SizedBox(width: 4.0),
Text('التاريخ: ${sell['transaction_date']}'),
],
),
],
),
onTap: () async {
setState(() => selectedSell = sell);
await fetchProductsForSell(sell['id']);
},
),
);
},
),
),
],
if ((!showSellList || widget.saleId != null) &&
selectedSell != null)
Expanded(
child: buildReturnForm(),
),
],
),
);
}

Widget buildReturnForm() {
return SingleChildScrollView(
child: Card(
margin: EdgeInsets.all(16),
child: Padding(
padding: EdgeInsets.all(16),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Container(
padding: EdgeInsets.all(12),
decoration: BoxDecoration(
color: Colors.blue[50],
borderRadius: BorderRadius.circular(8),
),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
'تفاصيل الفاتورة',
style: TextStyle(
fontSize: 18, fontWeight: FontWeight.bold),
),
SizedBox(height: 8),
Row(
children: [
Icon(Icons.receipt, size: 16),
SizedBox(width: 4),
Text('رقم الفاتورة: ${selectedSell!['invoice_no']}'),
],
),
SizedBox(height: 4),
Row(
children: [
Icon(Icons.person, size: 16),
SizedBox(width: 4),
Text('العميل: ${selectedSell!['customer_name']}'),
],
),
SizedBox(height: 4),
Row(
children: [
Icon(Icons.monetization_on, size: 16),
SizedBox(width: 4),
Text('المبلغ: $symbol ${selectedSell!['invoice_amount']}'),
],
),
],
),
),
SizedBox(height: 16),
TextFormField(
controller: returnDateController,
decoration: InputDecoration(
labelText: 'تاريخ الإرجاع',
suffixIcon: Icon(Icons.calendar_today),
),
readOnly: true,
onTap: _selectReturnDate,
),
SizedBox(height: 16),
TextFormField(
controller: returnNoteController,
decoration: InputDecoration(
labelText: 'ملاحظة (اختياري)',
),
maxLines: 3,
),
SizedBox(height: 16),
Text('المتغيرات:',
style: TextStyle(fontWeight: FontWeight.bold)),
buildSelectedProducts(),
SizedBox(height: 16),
ElevatedButton(
onPressed: handleReturnSubmit,
child: Text('إتمام الإرجاع'),
),
],
),
),
),
);
}

Widget buildSelectedProducts() {
return ListView.builder(
shrinkWrap: true,
itemCount: selectedProducts.length,
itemBuilder: (context, index) {
var product = selectedProducts[index];
return Card(
margin: EdgeInsets.symmetric(vertical: 4),
child: Padding(
padding: EdgeInsets.all(8),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
product['name'] ?? 'NaN',
style: TextStyle(fontWeight: FontWeight.bold),
),
SizedBox(height: 8),
Row(
children: [
Text('الكمية المتاحة: ${product['quantity']}'),
SizedBox(width: 8),
Text('السعر: $symbol ${product['unit_price']}'),
],
),
SizedBox(height: 8),
TextFormField(
initialValue: product['returnQuantity'].toString(),
keyboardType: TextInputType.number,
decoration: InputDecoration(
labelText: 'الكمية المراد إرجاعها',
border: OutlineInputBorder(),
),
onChanged: (value) {
setState(() {
double inputValue = double.tryParse(value) ?? 0;
double maxQuantity = product['quantity'] ?? 0;
product['returnQuantity'] =
inputValue > maxQuantity ? maxQuantity : inputValue;
});
},
),
],
),
),
);
},
);
}

Future<void> _selectReturnDate() async {
DateTime? selectedDate = await showDatePicker(
context: context,
initialDate: DateTime.now(),
firstDate: DateTime(2000),
lastDate: DateTime(2101),
);
if (selectedDate != null) {
setState(() {
returnDateController.text =
DateFormat('yyyy-MM-dd').format(selectedDate);
});
}
}

void handleReturnSubmit() async {
  print('handleReturnSubmit called'); // Debug statement

  if (returnDateController.text.isEmpty) {
    Fluttertoast.showToast(msg: 'يرجى تحديد تاريخ الإرجاع');
    print('Return date is empty'); // Debug statement
    return;
  }

  if (selectedProducts.isEmpty ||
      selectedProducts.every((p) => p['returnQuantity'] <= 0)) {
    Fluttertoast.showToast(msg: 'يرجى تحديد الكمية المراد إرجاعها');
    print('No products selected for return'); // Debug statement
    return;
  }

  setState(() => isLoading = true);
  print('Loading started'); // Debug statement

  try {
    List<Map<String, dynamic>> returnedProducts = [];
    for (var product in selectedProducts) {
      if (product['returnQuantity'] > 0) {
        returnedProducts.add({
          'product_id': product['product_id'],
          'variation_id': product['variation_id'],
          'quantity': product['returnQuantity'],
          'unit_price': product['unit_price'],
          'unit_price_inc_tax': product['unit_price'], // Add this line
        });
      }
    }
    String formattedDate = DateTime.parse(returnDateController.text)
        .toIso8601String()
        .replaceAll('T', ' ')
        .replaceAll('Z', '');

    print('Returned products: $returnedProducts'); // Debug statement

    Map<String, dynamic> sellReturn = {
      'sell_id': selectedSell!['id'],
      'transaction_id': selectedSell!['id'],
      'transaction_date': formattedDate, // Use the formatted date
      'invoice_no': selectedSell!['invoice_no'],
      'discount_amount': 0.0,
      'discount_type': 'fixed',
      'products': jsonEncode(returnedProducts),
      'is_synced': 0,
    };

    print('Sell return data: $sellReturn'); // Debug statement

    await SellDatabase().storeSellReturn(sellReturn);
    print('Sell return stored in database'); // Debug statement

    await SellDatabase().returnProducts(selectedSell!['id'], returnedProducts);
    print('Products returned in database'); // Debug statement

    await SellApi().syncSellReturns();
    print('Sell returns synced'); // Debug statement

    Fluttertoast.showToast(msg: 'تم تسجيل الإرجاع بنجاح');
    Navigator.pop(context);
  } catch (e) {
    print('Error occurred: $e'); // Debug statement
    Fluttertoast.showToast(msg: 'فشل في تسجيل الإرجاع: $e');
  } finally {
    setState(() => isLoading = false);
    print('Loading finished'); // Debug statement
  }
}
}