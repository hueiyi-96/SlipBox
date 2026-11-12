import 'package:flutter/material.dart';

import 'receipt.dart';
import 'receipt_detail_page.dart';
import 'receipt_store.dart';

class ReceiptBrowsePage extends StatelessWidget {
  const ReceiptBrowsePage({
    super.key,
    required this.title,
    required this.store,
    required this.include,
  });

  final String title;
  final ReceiptStore store;
  final bool Function(Receipt receipt) include;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final receipts = store.receipts.where(include).toList();
          if (receipts.isEmpty) {
            return const Center(child: Text('No receipts in this view'));
          }
          return ListView.separated(
            itemCount: receipts.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final receipt = receipts[index];
              return ListTile(
                title: Text(receipt.merchant),
                subtitle: Text(
                  '${formatDate(receipt.purchasedOn)} · ${receipt.category}',
                ),
                trailing: Text('\$${formatMoney(receipt.totalCents)}'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (context) => ReceiptDetailPage(receipt: receipt),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
