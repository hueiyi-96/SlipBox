import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracepay/features/local_scan.dart';
import 'package:tracepay/features/receipt_capture.dart';
import 'package:tracepay/features/receipt_store.dart';
import 'package:tracepay/main.dart';

void main() {
  testWidgets('manual entry saves a receipt onto the list', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      TracePayApp(
        store: ReceiptStore(),
        capture: ReceiptCapture(),
        textReader: _UnusedReader(),
        extractionApi: null,
      ),
    );

    expect(find.text('No receipts yet'), findsOneWidget);

    await tester.tap(find.byKey(const Key('add-receipt')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('enter-details')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('merchant-field')),
      'Morning Cafe',
    );
    await tester.enterText(find.byKey(const Key('total-field')), '18.50');
    await tester.tap(find.byKey(const Key('save-receipt')));
    await tester.pumpAndSettle();

    expect(find.text('Morning Cafe'), findsOneWidget);
    expect(find.text('\$18.50'), findsOneWidget);
    expect(find.text('No receipts yet'), findsNothing);
  });
}

class _UnusedReader implements ReceiptTextReader {
  @override
  Future<List<ScanLine>> read(String path) async => const [];
}
