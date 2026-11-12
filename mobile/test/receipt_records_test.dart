import 'package:flutter_test/flutter_test.dart';
import 'package:tracepay/features/receipt.dart';
import 'package:tracepay/features/receipt_records.dart';

void main() {
  final cafe = Receipt(
    id: '1',
    merchant: 'Morning Cafe',
    purchasedOn: DateTime(2026, 11, 12),
    totalCents: 1850,
    category: 'Food',
    receiptNumber: 'A-100',
    usage: 'business',
    gstShownCents: 241,
    gstClaimCents: 241,
    localFilePath: '/tmp/cafe.jpg',
  );
  final stationery = Receipt(
    id: '2',
    merchant: 'Office Shop',
    purchasedOn: DateTime(2026, 11, 13),
    totalCents: 4000,
    category: 'Supplies',
    usage: 'mixed',
    items: const [ReceiptItem(description: 'Paper', amountCents: 800)],
    gstShownCents: 104,
    gstClaimCents: 104,
    gstNeedsReview: true,
  );
  final lunch = Receipt(
    id: '3',
    merchant: 'Personal Lunch',
    purchasedOn: DateTime(2026, 11, 12),
    totalCents: 1500,
    category: 'Food',
  );

  test('search matches merchant or receipt number and can narrow by date', () {
    final byNumber = findReceipts([cafe, stationery, lunch], query: 'a-100');
    expect(byNumber.map((receipt) => receipt.merchant), ['Morning Cafe']);

    final oneDay = findReceipts(
      [cafe, stationery, lunch],
      from: DateTime(2026, 11, 13),
      to: DateTime(2026, 11, 13),
    );
    expect(oneDay.single.merchant, 'Office Shop');
  });

  test('category totals add every receipt in the period', () {
    final totals = categoryTotals(
      [cafe, stationery, lunch],
      from: DateTime(2026, 11, 1),
      to: DateTime(2026, 11, 30),
    );

    expect(totals.map((total) => total.category), ['Food', 'Supplies']);
    expect(totals.first.totalCents, 1850 + 1500);
    expect(totals.first.count, 2);
  });

  test(
    'export keeps personal receipts out and separates GST that needs review',
    () {
      final export = buildBusinessExport(
        [cafe, stationery, lunch],
        from: DateTime(2026, 11, 1),
        to: DateTime(2026, 11, 30),
      );

      expect(export.summary, contains('Morning Cafe'));
      expect(export.summary, contains('Office Shop'));
      expect(export.summary, isNot(contains('Personal Lunch')));
      expect(export.summary, contains('Confirmed GST: \$2.41'));
      expect(export.summary, contains('GST needing review: \$1.04'));
      expect(export.businessTotalCents, 1850 + 800);
      expect(export.filePaths, ['/tmp/cafe.jpg']);
    },
  );

  test('mixed items cannot add up to more than the receipt', () {
    expect(
      validateMixedItems(
        usage: 'mixed',
        totalCents: 1000,
        items: const [ReceiptItem(description: 'Paper', amountCents: 1200)],
      ),
      'Business items add up to more than the receipt total.',
    );
  });
}
