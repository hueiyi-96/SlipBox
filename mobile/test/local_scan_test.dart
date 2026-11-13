import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tracepay/core/config.dart';
import 'package:tracepay/core/network.dart';
import 'package:tracepay/features/local_scan.dart';

void main() {
  test('reads merchant, date, and total while ignoring the subtotal', () {
    final result = readReceiptText(const [
      ScanLine('TAX INVOICE', 10),
      ScanLine('Morning Cafe', 40),
      ScanLine('12 Nov 2026', 80),
      ScanLine('SUBTOTAL 16.09', 200),
      ScanLine('TOTAL 18.50', 240),
    ]);

    expect(result.merchant, 'Morning Cafe');
    expect(result.purchasedOn, DateTime(2026, 11, 12));
    expect(result.totalCents, 1850);
    expect(result.isComplete, isTrue);
  });

  test('treats a slash date as day month year', () {
    final result = readReceiptText(const [
      ScanLine('Corner Dairy', 20),
      ScanLine('12/11/2026', 60),
    ]);

    expect(result.purchasedOn, DateTime(2026, 11, 12));
    expect(result.totalCents, isNull);
    expect(result.isComplete, isFalse);
  });

  test('a complete local read does not call the worker', () async {
    final coordinator = ScanCoordinator(
      textReader: _FixedReader(const [
        ScanLine('Morning Cafe', 10),
        ScanLine('2026-11-12', 40),
        ScanLine('TOTAL 4.50', 80),
      ]),
      extractionApi: ReceiptExtractionApi(
        config: TracePayConfig.local,
        client: MockClient((request) async => fail('worker was called')),
      ),
    );

    final draft = await coordinator.fromImage(
      path: 'receipt.jpg',
      bytes: [1],
      sha256: 'abc',
    );

    expect(draft.extractionSource, 'local_mlkit');
    expect(draft.merchant, 'Morning Cafe');
    expect(draft.totalCents, 450);
    expect(draft.note, isNull);
  });

  test(
    'an incomplete local read uses the worker for the missing total',
    () async {
      final coordinator = ScanCoordinator(
        textReader: _FixedReader(const [
          ScanLine('Morning Cafe', 10),
          ScanLine('2026-11-12', 40),
        ]),
        extractionApi: ReceiptExtractionApi(
          config: const TracePayConfig(
            apiBaseUrl: 'https://api.tracepay.app',
            apiToken: 'token',
          ),
          client: MockClient((request) async {
            return http.Response(
              '{"fileKey":"receipts/abc","merchant":"Morning Cafe","purchasedOn":"2026-11-12","totalCents":1850,"taxCents":241,"currency":"NZD","receiptNumber":null}',
              200,
            );
          }),
        ),
      );

      final draft = await coordinator.fromImage(
        path: 'receipt.jpg',
        bytes: [1],
        sha256: 'abc',
      );

      expect(draft.extractionSource, 'cloud_ocr');
      expect(draft.totalCents, 1850);
      expect(draft.currency, 'NZD');
      expect(draft.note, isNull);
    },
  );

  test('parses NZD70.60, RM20,000.40, comma decimals, and thousands', () {
    final nz = readReceiptText(const [
      ScanLine('Auckland Books', 10),
      ScanLine('12 Nov 2026', 30),
      ScanLine('TOTAL NZD70.60', 60),
    ]);
    expect(nz.totalCents, 7060);
    expect(nz.currency, 'NZD');

    final my = readReceiptText(const [
      ScanLine('KL Electronics', 10),
      ScanLine('12/11/2026', 30),
      ScanLine('TOTAL RM20,000.40', 60),
    ]);
    expect(my.totalCents, 2000040);
    expect(my.currency, 'MYR');

    final commaDecimal = readReceiptText(const [
      ScanLine('Berlin Bakery', 10),
      ScanLine('2026-11-12', 30),
      ScanLine('TOTAL €20.000,40', 60),
    ]);
    expect(commaDecimal.totalCents, 2000040);
    expect(commaDecimal.currency, 'EUR');

    final thousandsOnly = readReceiptText(const [
      ScanLine('Baghdad Market', 10),
      ScanLine('2026-11-12', 30),
      ScanLine('TOTAL 25,000 IQD', 60),
    ]);
    expect(thousandsOnly.totalCents, 2500000);
    expect(thousandsOnly.currency, 'IQD');
  });
}

class _FixedReader implements ReceiptTextReader {
  _FixedReader(this.lines);

  final List<ScanLine> lines;

  @override
  Future<List<ScanLine>> read(String path) async => lines;
}
