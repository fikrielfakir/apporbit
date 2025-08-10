import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pos_final/api_end_points.dart';
import 'api.dart';
import '../models/stock_transfer.dart';

class StockTransferApi {
  final Api _api;

  StockTransferApi(this._api);

  Future<StockTransfer> getStockTransfer({
    required String token,
    required String transferId,
  }) async {
    final response = await _api.authenticatedRequest(
      endpoint: ApiEndPoints.getStockTransfer(transferId),
      method: 'GET',
      token: token,
    );

    if (response['success'] == true) {
      return StockTransfer.fromJson(response['data']);
    } else {
      throw StockTransferException(response['error'] ?? 'Failed to fetch transfer');
    }
  }

  Future<List<StockTransfer>> getAllTransfers({
    required String token,
    int page = 1,
    int perPage = 20,
    int? currentLocationId,
    String? status,
    DateTimeRange? dateRange,
    String? searchTerm,
  }) async {
    String endpoint = '${ApiEndPoints.stockTransfers}?page=$page&per_page=$perPage';

    if (currentLocationId != null) {
      endpoint += '&current_location_id=$currentLocationId';
    }
    if (status != null) endpoint += '&status=$status';
    if (dateRange != null) {
      endpoint += '&start_date=${_formatDate(dateRange.start)}'
          '&end_date=${_formatDate(dateRange.end)}';
    }
    if (searchTerm != null && searchTerm.isNotEmpty) {
      endpoint += '&search_term=$searchTerm';
    }

    final response = await _api.authenticatedRequest(
      endpoint: endpoint,
      method: 'GET',
      token: token,
    );

    if (response['success'] == true) {
      final data = response['data']['data'] as List;
      return data.map((json) => StockTransfer.fromJson(json)).toList();
    } else {
      throw StockTransferException(response['error'] ?? 'Failed to fetch transfers');
    }
  }

  Future<StockTransfer> createStockTransfer({
    required String token,
    required int locationId,
    required int transferLocationId,
    required String transactionDate,
    required List<StockTransferLine> products,
    required String refNo,
    required double shippingCharges,
    String? additionalNotes,
    String? status,
  }) async {
    final response = await _api.authenticatedRequest(
      endpoint: ApiEndPoints.stockTransfers,
      method: 'POST',
      token: token,
      body: {
        'location_id': locationId,
        'transfer_location_id': transferLocationId,
        'transaction_date': transactionDate,
        'products': products.map((p) => p.toJson()).toList(),
        'ref_no': refNo,
        'shipping_charges': shippingCharges,
        'additional_notes': additionalNotes,
        'status': status ?? 'pending',
      },
    );

    if (response['success'] == true) {
      return StockTransfer.fromJson(response['data']);
    } else {
      throw StockTransferException(response['error'] ?? 'Failed to create transfer');
    }
  }

  Future<StockTransfer> updateStockTransfer({
    required String token,
    required String transferId,
    int? locationId,
    int? transferLocationId,
    String? transactionDate,
    List<StockTransferLine>? products,
    String? refNo,
    double? shippingCharges,
    String? additionalNotes,
    String? status,
  }) async {
    final body = <String, dynamic>{};
    if (locationId != null) body['location_id'] = locationId;
    if (transferLocationId != null) body['transfer_location_id'] = transferLocationId;
    if (transactionDate != null) body['transaction_date'] = transactionDate;
    if (products != null) body['products'] = products.map((p) => p.toJson()).toList();
    if (refNo != null) body['ref_no'] = refNo;
    if (shippingCharges != null) body['shipping_charges'] = shippingCharges;
    if (additionalNotes != null) body['additional_notes'] = additionalNotes;
    if (status != null) body['status'] = status;

    final response = await _api.authenticatedRequest(
      endpoint: ApiEndPoints.updateStockTransfer(transferId),
      method: 'PUT',
      token: token,
      body: body,
    );

    if (response['success'] == true) {
      return StockTransfer.fromJson(response['data']);
    } else {
      throw StockTransferException(response['error'] ?? 'Failed to update transfer');
    }
  }

  Future<bool> deleteStockTransfer({
    required String token,
    required String transferId,
  }) async {
    final response = await _api.authenticatedRequest(
      endpoint: ApiEndPoints.deleteStockTransfer(transferId),
      method: 'DELETE',
      token: token,
    );

    if (response['success'] == true) {
      return true;
    } else {
      throw StockTransferException(response['error'] ?? 'Failed to delete transfer');
    }
  }

  Future<StockTransfer> updateStockTransferStatus({
    required String token,
    required String transferId,
    required String status,
    String? notes,
  }) async {
    if (!['pending', 'in_transit', 'completed'].contains(status)) {
      throw StockTransferException('Invalid status value');
    }

    try {
      final response = await _api.authenticatedRequest(
        endpoint: ApiEndPoints.updateStockTransferStatus(transferId),
        method: 'PUT', // Changed from POST to PUT
        token: token,
        body: {
          'status': status,
          if (notes != null) 'notes': notes,
        },
      );

      if (response['success'] == true) {
        return StockTransfer.fromJson(response['data']);
      } else {
        throw StockTransferException(
          response['error'] ?? 'Failed to update status',
          statusCode: response['statusCode'],
        );
      }
    } catch (e) {
      // Add detailed error logging
      print('Error updating status: $e');
      print('Endpoint: ${ApiEndPoints.updateStockTransferStatus(transferId)}');
      print('Status attempted: $status');
      rethrow;
    }
  }

  Future<String> printInvoice({
    required String token,
    required String transferId,
  }) async {
    final response = await _api.authenticatedRequest(
      endpoint: ApiEndPoints.printStockTransferInvoice(transferId),
      method: 'GET',
      token: token,
    );

    if (response['success'] == true) {
      return response['data']['html'] ?? '';
    } else {
      throw StockTransferException(response['error'] ?? 'Failed to print invoice');
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }
}

class StockTransferException implements Exception {
  final String message;
  final int? statusCode;

  StockTransferException(this.message, {this.statusCode});

  @override
  String toString() => 'StockTransferException: $message'
      '${statusCode != null ? ' (Status: $statusCode)' : ''}';
}