import 'receipt.dart';

class CategoryTotal {
  const CategoryTotal({
    required this.category,
    required this.totalCents,
    required this.count,
  });

  final String category;
  final int totalCents;
  final int count;
}

class BusinessExport {
  const BusinessExport({
    required this.summary,
    required this.filePaths,
    required this.businessTotalCents,
  });

  final String summary;
  final List<String> filePaths;
  final int businessTotalCents;
}

List<Receipt> findReceipts(
  List<Receipt> receipts, {
  String query = '',
  DateTime? from,
  DateTime? to,
  String? category,
}) {
  final text = query.trim().toLowerCase();
  return [
    for (final receipt in receipts)
      if (_matchesText(receipt, text) &&
          _inPeriod(receipt.purchasedOn, from, to) &&
          (category == null || receipt.category == category))
        receipt,
  ];
}

List<CategoryTotal> categoryTotals(
  List<Receipt> receipts, {
  required DateTime from,
  required DateTime to,
}) {
  final totals = <String, CategoryTotal>{};
  for (final receipt in findReceipts(receipts, from: from, to: to)) {
    final current = totals[receipt.category];
    totals[receipt.category] = CategoryTotal(
      category: receipt.category,
      totalCents: (current?.totalCents ?? 0) + receipt.totalCents,
      count: (current?.count ?? 0) + 1,
    );
  }
  final ordered = <CategoryTotal>[];
  for (final category in receiptCategories) {
    final total = totals.remove(category);
    if (total != null) {
      ordered.add(total);
    }
  }
  ordered.addAll(totals.values);
  return ordered;
}

BusinessExport buildBusinessExport(
  List<Receipt> receipts, {
  required DateTime from,
  required DateTime to,
}) {
  final included = [
    for (final receipt in findReceipts(receipts, from: from, to: to))
      if (businessCents(receipt) > 0) receipt,
  ];
  final confirmed = [
    for (final receipt in included)
      if (!receipt.gstNeedsReview) receipt,
  ];
  final review = [
    for (final receipt in included)
      if (receipt.gstNeedsReview) receipt,
  ];
  final lines = <String>[
    'TracePay business expenses',
    '${formatDate(from)} – ${formatDate(to)}',
    '',
    'Confirmed',
    if (confirmed.isEmpty) 'None',
    for (final receipt in confirmed) _exportLine(receipt),
    '',
    'Needs review',
    if (review.isEmpty) 'None',
    for (final receipt in review) _exportLine(receipt),
    '',
    'Business total: \$${formatMoney(_sumBusiness(included))}',
    'Confirmed GST: \$${formatMoney(_sumGst(confirmed))}',
    'GST needing review: \$${formatMoney(_sumGst(review))}',
  ];
  return BusinessExport(
    summary: lines.join('\n'),
    filePaths: [
      for (final receipt in included)
        if (receipt.localFilePath != null) receipt.localFilePath!,
    ],
    businessTotalCents: _sumBusiness(included),
  );
}

String? validateMixedItems({
  required String usage,
  required int totalCents,
  required List<ReceiptItem> items,
}) {
  if (usage != 'mixed') {
    return null;
  }
  if (items.isEmpty) {
    return 'Add the business items and their amounts.';
  }
  final sum = items.fold(0, (total, item) => total + item.amountCents);
  if (sum > totalCents) {
    return 'Business items add up to more than the receipt total.';
  }
  return null;
}

bool _matchesText(Receipt receipt, String text) {
  if (text.isEmpty) {
    return true;
  }
  return receipt.merchant.toLowerCase().contains(text) ||
      (receipt.receiptNumber?.toLowerCase().contains(text) ?? false);
}

bool _inPeriod(DateTime day, DateTime? from, DateTime? to) {
  final date = DateTime(day.year, day.month, day.day);
  if (from != null &&
      date.isBefore(DateTime(from.year, from.month, from.day))) {
    return false;
  }
  if (to != null && date.isAfter(DateTime(to.year, to.month, to.day))) {
    return false;
  }
  return true;
}

String _exportLine(Receipt receipt) {
  final gst = receipt.gstClaimCents == null
      ? ''
      : ', GST claim \$${formatMoney(receipt.gstClaimCents!)}';
  final shown = receipt.gstShownCents == null
      ? ''
      : ', GST shown \$${formatMoney(receipt.gstShownCents!)}';
  return '${receipt.merchant}, ${formatDate(receipt.purchasedOn)}, ${receipt.category}, \$${formatMoney(businessCents(receipt))}$shown$gst';
}

int _sumBusiness(List<Receipt> receipts) {
  return receipts.fold(0, (sum, receipt) => sum + businessCents(receipt));
}

int _sumGst(List<Receipt> receipts) {
  return receipts.fold(0, (sum, receipt) => sum + (receipt.gstClaimCents ?? 0));
}
