import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tracepay/features/receipt.dart';
import 'package:tracepay/features/receipt_store.dart';

void main() {
  test('saved receipts load back from the file', () async {
    final file = File(
      '${Directory.systemTemp.path}/tracepay-${DateTime.now().microsecondsSinceEpoch}.json',
    );
    final store = FileReceiptStore(file);
    store.add(
      Receipt(
        id: '1',
        merchant: 'Morning Cafe',
        purchasedOn: DateTime(2026, 11, 12),
        totalCents: 1850,
        category: 'Food',
        fileSha256: 'abc',
      ),
    );
    await store.persist();

    final loaded = FileReceiptStore(file);
    await loaded.load();

    expect(loaded.receipts.single.merchant, 'Morning Cafe');
    expect(loaded.hasHash('abc'), isTrue);
    expect(
      loaded.similarTo(DateTime(2026, 11, 12), 1850)?.merchant,
      'Morning Cafe',
    );
    await file.delete();
  });
}
