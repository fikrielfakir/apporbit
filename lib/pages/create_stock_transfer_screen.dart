import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../apis/api.dart';
import '../models/stock_transfer.dart';
import '../models/system.dart';
import '../providers/location_provider.dart';

class CreateStockTransferScreen extends StatefulWidget {
  const CreateStockTransferScreen({Key? key}) : super(key: key);

  @override
  _CreateStockTransferScreenState createState() => _CreateStockTransferScreenState();
}

class _CreateStockTransferScreenState extends State<CreateStockTransferScreen> {
  final _formKey = GlobalKey<FormState>();
  final _api = Api();
  DateTime _transferDate = DateTime.now();
  int? _fromLocationId;
  int? _toLocationId;
  final TextEditingController _refNoController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _shippingController = TextEditingController(
      text: '0.00');
  bool _isSaving = false;
  final List<StockTransferLine> _products = [];

  @override
  Widget build(BuildContext context) {
    final locationProvider = Provider.of<LocationProvider>(context);
    final locations = locationProvider.locations;

    return Scaffold(

      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _refNoController,
                decoration: InputDecoration(
                  labelText: 'Reference Number',
                  hintText: 'ST-2023-001',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a reference number';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              ListTile(
                title: Text('Transfer Date'),
                subtitle: Text(
                    DateFormat('MMM dd, yyyy').format(_transferDate)),
                trailing: Icon(Icons.calendar_today),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _transferDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(Duration(days: 365)),
                  );
                  if (date != null) {
                    setState(() => _transferDate = date);
                  }
                },
              ),
              SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: _fromLocationId,
                decoration: InputDecoration(labelText: 'From Location'),
                items: locations.map((location) {
                  return DropdownMenuItem<int>(
                    value: location['id'],
                    child: Text('${location['name']} (ID: ${location['id']})'),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _fromLocationId = value);
                },
                validator: (value) {
                  if (value == null) {
                    return 'Please select a location';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: _toLocationId,
                decoration: InputDecoration(labelText: 'To Location'),
                items: locations
                    .where((loc) => loc['id'] != _fromLocationId)
                    .map((location) {
                  return DropdownMenuItem<int>(
                    value: location['id'],
                    child: Text('${location['name']} (ID: ${location['id']})'),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _toLocationId = value);
                },
                validator: (value) {
                  if (value == null) {
                    return 'Please select a location';
                  }
                  if (value == _fromLocationId) {
                    return 'Must be different from source location';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _shippingController,
                decoration: InputDecoration(labelText: 'Shipping Charges'),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter shipping charges';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                decoration: InputDecoration(labelText: 'Additional Notes'),
                maxLines: 3,
              ),
              SizedBox(height: 24),
              Text('Products:', style: TextStyle(fontWeight: FontWeight.bold)),
              ..._products.map((product) =>
                  ListTile(
                    title: Text(product.productName),
                    subtitle: Text('${product.quantity} x \$${product.unitPrice
                        .toStringAsFixed(2)}'),
                    trailing: IconButton(
                      icon: Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _removeProduct(product),
                    ),
                  )),
              SizedBox(height: 16),
              ElevatedButton(
                child: Text('Add Product'),
                onPressed: () => _addProduct(),
              ),
              SizedBox(height: 24),
              Text(
                'Total: \$${_calculateTotal().toStringAsFixed(2)}',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _calculateTotal() {
    double subtotal = _products.fold(0, (sum, item) => sum + item.lineTotal);
    double shipping = double.tryParse(_shippingController.text) ?? 0;
    return subtotal + shipping;
  }

  Future<void> _addProduct() async {
    // TODO: Implement product selection
    // For now, adding a dummy product
    setState(() {
      _products.add(StockTransferLine(
        id: DateTime
            .now()
            .millisecondsSinceEpoch
            .toString(),
        productId: '1',
        variationId: '1',
        productName: 'Sample Product',
        variationName: 'Default',
        quantity: 1,
        unitPrice: 10.0,
        lineTotal: 10.0,
        subSku: '',
      ));
    });
  }

  void _removeProduct(StockTransferLine product) {
    setState(() {
      _products.remove(product);
    });
  }

}