import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tracepay/core/config.dart';
import 'package:tracepay/core/errors.dart';
import 'package:tracepay/core/network.dart';

void main() {
  test(
    'extract reads the worker response and ignores how it was scanned',
    () async {
      final api = ReceiptExtractionApi(
        config: const TracePayConfig(
          apiBaseUrl: 'https://api.tracepay.app',
          apiToken: 'local-dev-token',
        ),
        client: MockClient((request) async {
          expect(request.url.toString(), 'https://api.tracepay.app/extract');
          expect(request.headers['authorization'], 'Bearer local-dev-token');
          expect(request.headers['content-type'], 'image/jpeg');
          expect(request.bodyBytes, [1, 2, 3]);
          return http.Response(
            '{"fileKey":"receipts/abc","merchant":"Morning Cafe","purchasedOn":"2026-11-12","totalCents":1850,"taxCents":241,"currency":"NZD","receiptNumber":null}',
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final extracted = await api.extract([1, 2, 3], contentType: 'image/jpeg');

      expect(extracted.fileKey, 'receipts/abc');
      expect(extracted.merchant, 'Morning Cafe');
      expect(extracted.purchasedOn, DateTime.parse('2026-11-12'));
      expect(extracted.totalCents, 1850);
      expect(extracted.taxCents, 241);
      expect(extracted.currency, 'NZD');
    },
  );

  test('a failed scan surfaces the worker error', () async {
    final api = ReceiptExtractionApi(
      config: TracePayConfig.local,
      client: MockClient(
        (request) async => http.Response(
          '{"fileKey":"receipts/abc","error":"Receipt extraction is not configured."}',
          503,
        ),
      ),
    );

    expect(
      () => api.extract([1], contentType: 'image/jpeg'),
      throwsA(
        isA<ReceiptExtractionException>()
            .having(
              (error) => error.message,
              'message',
              'Receipt extraction is not configured.',
            )
            .having((error) => error.fileKey, 'fileKey', 'receipts/abc'),
      ),
    );
  });
}
