import 'dart:convert';

import 'package:http/http.dart' as http;

import '../features/extracted_receipt.dart';
import 'config.dart';
import 'errors.dart';
import 'security.dart';

/// Calls the TracePay Worker. The app never talks to an OCR provider itself.
class ReceiptExtractionApi {
  ReceiptExtractionApi({required this.config, http.Client? client})
    : _client = client ?? http.Client();

  final TracePayConfig config;
  final http.Client _client;

  Future<ExtractedReceipt> extract(
    List<int> bytes, {
    required String contentType,
  }) async {
    final response = await _client.post(
      Uri.parse('${config.apiBaseUrl}/extract'),
      headers: apiHeaders(config, contentType: contentType),
      body: bytes,
    );
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const ReceiptExtractionException(
        'The scan service sent an unexpected response.',
      );
    }
    final body = Map<String, Object?>.from(decoded);
    if (response.statusCode != 200) {
      final message =
          body['error'] as String? ??
          'The scan service could not read that receipt.';
      throw ReceiptExtractionException(
        message,
        fileKey: body['fileKey'] as String?,
      );
    }
    return ExtractedReceipt.fromJson(body);
  }
}
