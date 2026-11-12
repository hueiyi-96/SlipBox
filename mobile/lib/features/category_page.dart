import 'package:flutter/material.dart';

import 'receipt.dart';
import 'receipt_browse_page.dart';
import 'receipt_records.dart';
import 'receipt_store.dart';

class CategoryPage extends StatefulWidget {
  const CategoryPage({super.key, required this.store});

  final ReceiptStore store;

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  late DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, 1);
  late DateTime _to = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Spending')),
      body: ListenableBuilder(
        listenable: widget.store,
        builder: (context, _) {
          final totals = categoryTotals(
            widget.store.receipts,
            from: _from,
            to: _to,
          );
          return ListView(
            children: [
              ListTile(
                title: Text('${formatDate(_from)} – ${formatDate(_to)}'),
                trailing: const Icon(Icons.date_range),
                onTap: _pickRange,
              ),
              if (totals.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No spending in this period.'),
                ),
              for (final total in totals)
                ListTile(
                  title: Text(total.category),
                  subtitle: Text(
                    '${total.count} ${total.count == 1 ? 'receipt' : 'receipts'}',
                  ),
                  trailing: Text('\$${formatMoney(total.totalCents)}'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (context) => ReceiptBrowsePage(
                          title: total.category,
                          store: widget.store,
                          include: (receipt) =>
                              receipt.category == total.category &&
                              !receipt.purchasedOn.isBefore(_from) &&
                              !DateTime(
                                receipt.purchasedOn.year,
                                receipt.purchasedOn.month,
                                receipt.purchasedOn.day,
                              ).isAfter(_to),
                        ),
                      ),
                    );
                  },
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _pickRange() async {
    final from = await showDatePicker(
      context: context,
      initialDate: _from,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (from == null || !mounted) {
      return;
    }
    final to = await showDatePicker(
      context: context,
      initialDate: _to.isBefore(from) ? from : _to,
      firstDate: from,
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (to == null) {
      return;
    }
    setState(() {
      _from = DateTime(from.year, from.month, from.day);
      _to = DateTime(to.year, to.month, to.day);
    });
  }
}
