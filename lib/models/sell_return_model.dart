class SellReturnModel {
  final int id;
  final int businessId;
  final int locationId;
  final String type;
  final String status;
  final String invoiceNo;
  final String transactionDate;
  final double totalBeforeTax;
  final double taxAmount;
  final String discountType;
  final double discountAmount;
  final double finalTotal;
  final List<dynamic> products;

  SellReturnModel({
    required this.id,
    required this.businessId,
    required this.locationId,
    required this.type,
    required this.status,
    required this.invoiceNo,
    required this.transactionDate,
    required this.totalBeforeTax,
    required this.taxAmount,
    required this.discountType,
    required this.discountAmount,
    required this.finalTotal,
    required this.products,
  });

  factory SellReturnModel.fromJson(Map<String, dynamic> json) {
    return SellReturnModel(
      id: json['id'],
      businessId: json['business_id'],
      locationId: json['location_id'],
      type: json['type'],
      status: json['status'],
      invoiceNo: json['invoice_no'],
      transactionDate: json['transaction_date'],
      totalBeforeTax: double.parse(json['total_before_tax'].toString()),
      taxAmount: double.parse(json['tax_amount'].toString()),
      discountType: json['discount_type'],
      discountAmount: double.parse(json['discount_amount'].toString()),
      finalTotal: double.parse(json['final_total'].toString()),
      products: json['products'],
    );
  }
}