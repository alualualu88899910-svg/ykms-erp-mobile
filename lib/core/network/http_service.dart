import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../shared/providers/connection_provider.dart';

class HttpService {
  final Ref _ref;
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 20),
  ));

  HttpService(this._ref);

  String get _baseUrl {
    final connectionState = _ref.read(connectionProvider);
    final ip = connectionState.ipAddress;
    if (ip == null || ip.isEmpty) {
      throw Exception("لا يوجد عنوان IP متصل");
    }
    return 'http://$ip:8766';
  }

  /// Uploads a compressed product photo to the desktop server.
  /// Uses raw binary stream because the Electron server pipes the request directly to fs.createWriteStream.
  Future<bool> uploadProductImage(int productId, XFile imageFile, {bool isPrimary = false}) async {
    try {
      final url = '$_baseUrl/upload-image';
      final bytes = await imageFile.readAsBytes();
      
      final response = await _dio.post(
        url,
        data: bytes,
        queryParameters: {
          'productId': productId.toString(),
          'isPrimary': isPrimary.toString(),
        },
        options: Options(
          headers: {
            Headers.contentTypeHeader: 'application/octet-stream',
            Headers.contentLengthHeader: bytes.length,
          },
        ),
      );

      if (response.statusCode == 200) {
        _ref.read(connectionProvider.notifier).incrementImagesSent();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("HTTP Upload Product Image Error: $e");
      return false;
    }
  }

  /// Uploads a compressed invoice photo to the desktop server.
  /// Uses raw binary stream because the Electron server pipes the request directly to fs.createWriteStream.
  Future<bool> uploadInvoiceImage(XFile invoiceFile) async {
    try {
      final url = '$_baseUrl/upload-invoice';
      final bytes = await invoiceFile.readAsBytes();
      
      final response = await _dio.post(
        url,
        data: bytes,
        options: Options(
          headers: {
            Headers.contentTypeHeader: 'application/octet-stream',
            Headers.contentLengthHeader: bytes.length,
          },
        ),
      );

      if (response.statusCode == 200) {
        _ref.read(connectionProvider.notifier).incrementInvoicesSent();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("HTTP Upload Invoice Image Error: $e");
      return false;
    }
  }

  /// Links a new/alternative barcode to an existing product in the database.
  Future<bool> linkBarcode(int productId, String barcode) async {
    try {
      final url = '$_baseUrl/link-barcode';
      final response = await _dio.post(
        url,
        queryParameters: {
          'productId': productId.toString(),
          'barcode': barcode,
        },
      );
      if (response.statusCode == 200) {
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("HTTP Link Barcode Error: $e");
      return false;
    }
  }

  /// Fetches a list of products by query from the ERP database.
  Future<List<Map<String, dynamic>>> searchProducts(String query) async {
    try {
      final url = '$_baseUrl/search-products';
      final response = await _dio.get(url, queryParameters: {'query': query});
      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> list = response.data;
        return list.map((item) => Map<String, dynamic>.from(item)).toList();
      }
      return [];
    } catch (e) {
      debugPrint("HTTP Search Products Error: $e");
      return [];
    }
  }

  /// Fetches the active counting session from the server (if any).
  Future<Map<String, dynamic>?> getActiveInventorySession() async {
    try {
      final url = '$_baseUrl/icount/active-session';
      final response = await _dio.get(url);
      if (response.statusCode == 200 && response.data != null && response.data['success'] == true) {
        return response.data['session'] != null ? Map<String, dynamic>.from(response.data['session']) : null;
      }
      return null;
    } catch (e) {
      debugPrint("HTTP Get Active Inventory Session Error: $e");
      return null;
    }
  }

  /// Searches for products inside the active counting session.
  Future<List<Map<String, dynamic>>> searchInventoryItems(int sessionId, String query) async {
    try {
      final url = '$_baseUrl/icount/search-item';
      final response = await _dio.get(
        url,
        queryParameters: {
          'sessionId': sessionId.toString(),
          'query': query,
        },
      );
      if (response.statusCode == 200 && response.data != null && response.data['success'] == true) {
        final List<dynamic> list = response.data['items'] ?? [];
        return list.map((item) => Map<String, dynamic>.from(item)).toList();
      }
      return [];
    } catch (e) {
      debugPrint("HTTP Search Inventory Items Error: $e");
      return [];
    }
  }

  /// Updates the counted quantity and optional notes/reasons for an item.
  Future<Map<String, dynamic>?> updateInventoryCount({
    required int sessionId,
    required int itemId,
    required double countedQty,
    String? notes,
    String? mismatchReason,
  }) async {
    try {
      final url = '$_baseUrl/icount/update-count';
      final Map<String, dynamic> data = {
        'session_id': sessionId,
        'item_id': itemId,
        'counted_qty': countedQty,
      };
      if (notes != null) {
        data['notes'] = notes;
      }
      if (mismatchReason != null) {
        data['mismatch_reason'] = mismatchReason;
      }

      final response = await _dio.post(
        url,
        data: data,
      );
      if (response.statusCode == 200 && response.data != null && response.data['success'] == true) {
        return Map<String, dynamic>.from(response.data);
      }
      return null;
    } catch (e) {
      debugPrint("HTTP Update Inventory Count Error: $e");
      return null;
    }
  }
}

final httpServiceProvider = Provider<HttpService>((ref) {
  return HttpService(ref);
});
