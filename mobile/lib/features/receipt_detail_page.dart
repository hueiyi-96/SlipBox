import 'dart:io';

import 'package:flutter/material.dart';

import 'receipt.dart';

class ReceiptDetailPage extends StatelessWidget {
  const ReceiptDetailPage({super.key, required this.receipt});

  final Receipt receipt;

  @override
  Widget build(BuildContext context) {
    final path = receipt.localFilePath;
    final isPdf = path != null && path.toLowerCase().endsWith('.pdf');
    return Scaffold(
      appBar: AppBar(title: Text(receipt.merchant)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (path != null && !isPdf && File(path).existsSync())
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(File(path), height: 220, fit: BoxFit.cover),
              ),
            ),
          if (isPdf) const Text('Original PDF saved with this receipt.'),
          _row('Date', formatDate(receipt.purchasedOn)),
          _row('Total', '\$${formatMoney(receipt.totalCents)}'),
          _row('Category', receipt.category),
          _row('Use', usageLabel(receipt.usage)),
          if (receipt.receiptNumber != null)
            _row('Receipt number', receipt.receiptNumber!),
          if (receipt.usage == 'mixed')
            for (final item in receipt.items)
              _row(item.description, '\$${formatMoney(item.amountCents)}'),
          if (receipt.gstShownCents != null)
            _row('GST shown', '\$${formatMoney(receipt.gstShownCents!)}'),
          if (receipt.gstClaimCents != null)
            _row('GST to claim', '\$${formatMoney(receipt.gstClaimCents!)}'),
          if (receipt.gstNeedsReview) _row('GST', 'Needs review'),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(width: 140, child: Text(label)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
