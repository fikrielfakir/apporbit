import 'package:intl/intl.dart';

class StockTransfer {
  final String id;
  final String refNo;
  final String status;
  final DateTime transactionDate;
  final int locationId;
  final String locationName;
  final int transferLocationId;
  final String transferLocationName;
  final double finalTotal;
  final double shippingCharges;
  final String? additionalNotes;
  final List<StockTransferLine> lines;
  final Transaction? purchaseTransfer;
  final Transaction? sellTransfer;
  final int createdBy;
  final int demandeurId; // Add this line
  final DateTime createdAt;
  final DateTime updatedAt;

  StockTransfer({
    required this.id,
    required this.refNo,
    required this.status,
    required this.transactionDate,
    required this.locationId,
    required this.locationName,
    required this.transferLocationId,
    required this.transferLocationName,
    required this.finalTotal,
    required this.shippingCharges,
    this.additionalNotes,
    required this.lines,
    this.purchaseTransfer,
    this.sellTransfer,
    required this.createdBy,
    required this.demandeurId, // Add this line
    required this.createdAt,
    required this.updatedAt,
  });

  factory StockTransfer.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? json;
    print('Parsing transfer: ${data['id']}, demandeur_id: ${data['demandeur_id']}'); // Debug log


    // Handle locations from different possible API structures
    final locationFrom = data['location_from'] ?? data['location'];
    final locationTo = data['location_to'] ??
        data['transfer_location'] ??
        data['purchase_transfer']?['location'];

    return StockTransfer(
      id: data['id']?.toString() ?? '',
      refNo: data['ref_no']?.toString() ?? 'ST-${data['id']}',
      status: (data['status']?.toString() ?? 'pending').toLowerCase(),
      transactionDate: _parseDateTime(data['transaction_date']),
      locationId: _parseInt(data['location_id'] ?? locationFrom?['id']),
      locationName: locationFrom?['name']?.toString() ?? 'Unknown Location',
      transferLocationId: _parseInt(data['transfer_location_id'] ?? locationTo?['id']),
      transferLocationName: locationTo?['name']?.toString() ?? 'Unknown Location',
      finalTotal: _parseDouble(data['final_total'] ?? 0),
      shippingCharges: _parseDouble(data['shipping_charges'] ?? 0),
      additionalNotes: data['additional_notes']?.toString(),
      lines: _parseTransferLines(data),
      purchaseTransfer: data['purchase_transfer'] is Map
          ? Transaction.fromJson(data['purchase_transfer'])
          : null,
      sellTransfer: data['sell_transfer'] is Map
          ? Transaction.fromJson(data['sell_transfer'])
          : null,
      createdBy: _parseInt(data['created_by']),
      demandeurId: _parseInt(data['demandeur_id']), // Add this line
      createdAt: _parseDateTime(data['created_at']),
      updatedAt: _parseDateTime(data['updated_at']),
    );
  }

  static int _parseInt(dynamic value) => value == null ? 0 : value is int ? value : int.tryParse(value.toString()) ?? 0;

  static double _parseDouble(dynamic value) => value == null ? 0.0 : value is double ? value : double.tryParse(value.toString()) ?? 0.0;

  static DateTime _parseDateTime(dynamic value) {
    try {
      if (value is DateTime) return value;
      if (value is String) {
        return value.contains('T')
            ? DateTime.parse(value)
            : DateFormat('yyyy-MM-dd HH:mm:ss').parse(value);
      }
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      return DateTime.now();
    } catch (e) {
      return DateTime.now();
    }
  }

  static List<StockTransferLine> _parseTransferLines(Map<String, dynamic> json) {
    try {
      final lines = json['sell_lines'] ?? json['transfer_lines'] ?? [];
      if (lines is List) {
        return lines.map<StockTransferLine>((line) {
          return StockTransferLine.fromJson(line);
        }).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  StockTransfer copyWith({
    String? id,
    String? refNo,
    String? status,
    DateTime? transactionDate,
    int? locationId,
    String? locationName,
    int? transferLocationId,
    String? transferLocationName,
    double? finalTotal,
    double? shippingCharges,
    String? additionalNotes,
    List<StockTransferLine>? lines,
    Transaction? purchaseTransfer,
    Transaction? sellTransfer,
    int? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StockTransfer(
      id: id ?? this.id,
      refNo: refNo ?? this.refNo,
      status: status ?? this.status,
      transactionDate: transactionDate ?? this.transactionDate,
      locationId: locationId ?? this.locationId,
      locationName: locationName ?? this.locationName,
      transferLocationId: transferLocationId ?? this.transferLocationId,
      transferLocationName: transferLocationName ?? this.transferLocationName,
      finalTotal: finalTotal ?? this.finalTotal,
      shippingCharges: shippingCharges ?? this.shippingCharges,
      additionalNotes: additionalNotes ?? this.additionalNotes,
      lines: lines ?? this.lines,
      purchaseTransfer: purchaseTransfer ?? this.purchaseTransfer,
      sellTransfer: sellTransfer ?? this.sellTransfer,
      createdBy: createdBy ?? this.createdBy,
      demandeurId: demandeurId ?? this.demandeurId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get formattedDate => DateFormat('MMM dd, yyyy').format(transactionDate);
  String get formattedTime => DateFormat('hh:mm a').format(transactionDate);
}

class StockTransferLine {
  final String id;
  final String productId;
  final String variationId;
  final String productName;
  final String variationName;
  final String? subSku;
  final double quantity;
  final double unitPrice;
  final double lineTotal;

  StockTransferLine({
    required this.id,
    required this.productId,
    required this.variationId,
    required this.productName,
    required this.variationName,
    this.subSku,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
  });

  factory StockTransferLine.fromJson(Map<String, dynamic> json) {
    return StockTransferLine(
      id: json['id']?.toString() ?? '',
      productId: json['product_id']?.toString() ?? '',
      variationId: json['variation_id']?.toString() ?? '',
      productName: json['product'] is Map
          ? json['product']['name']?.toString() ?? 'Unknown Product'
          : 'Unknown Product',
      variationName: json['variation'] is Map
          ? json['variation']['name']?.toString() ?? 'N/A'
          : 'N/A',
      subSku: json['variation'] is Map
          ? json['variation']['sub_sku']?.toString()
          : null,
      quantity: _parseDouble(json['quantity']),
      unitPrice: _parseDouble(json['unit_price']),
      lineTotal: _parseDouble(json['quantity']) * _parseDouble(json['unit_price']),
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'variation_id': variationId,
      'quantity': quantity,
      'unit_price': unitPrice,
    };
  }
}

class Transaction {
  final String id;
  final String refNo;
  final String status;
  final int transferLocationId;
  final String? locationName;

  Transaction({
    required this.id,
    required this.refNo,
    required this.status,
    required this.transferLocationId,
    this.locationName,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id']?.toString() ?? '',
      refNo: json['ref_no']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      transferLocationId: _parseInt(json['transfer_location_id']),
      locationName: json['location'] is Map ? json['location']['name']?.toString() : null,
    );
  }

  static int _parseInt(dynamic value) => value == null ? 0 : value is int ? value : int.tryParse(value.toString()) ?? 0;
}