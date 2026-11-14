import 'dart:io';

import 'package:flutter/material.dart';

import 'local_scan.dart';
import 'receipt.dart';
import 'receipt_records.dart';
import 'receipt_store.dart';

class ReceiptFormPage extends StatefulWidget {
  const ReceiptFormPage({super.key, required this.store, required this.draft});

  final ReceiptStore store;
  final ReceiptDraft draft;

  @override
  State<ReceiptFormPage> createState() => _ReceiptFormPageState();
}

class _ItemFields {
  final description = TextEditingController();
  final amount = TextEditingController();

  void dispose() {
    description.dispose();
    amount.dispose();
  }
}

class _ReceiptFormPageState extends State<ReceiptFormPage> {
  late final TextEditingController _merchant = TextEditingController(
    text: widget.draft.merchant ?? '',
  );
  late final TextEditingController _total = TextEditingController(
    text: widget.draft.totalCents == null
        ? ''
        : formatMoney(widget.draft.totalCents!),
  );
  late final TextEditingController _currency = TextEditingController(
    text: widget.draft.currency ?? '',
  );
  late final TextEditingController _number = TextEditingController(
    text: widget.draft.receiptNumber ?? '',
  );
  late final TextEditingController _gstShown = TextEditingController();
  late final TextEditingController _gstClaim = TextEditingController();
  late DateTime _date = _dateOnly(widget.draft.purchasedOn ?? DateTime.now());
  String _category = receiptCategories.first;
  String _usage = 'personal';
  bool _gstNeedsReview = false;
  final _items = <_ItemFields>[];
  String? _error;

  @override
  void dispose() {
    _merchant.dispose();
    _total.dispose();
    _currency.dispose();
    _number.dispose();
    _gstShown.dispose();
    _gstClaim.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final path = widget.draft.localFilePath;
    final note = widget.draft.note;
    final isPdf = path != null && path.toLowerCase().endsWith('.pdf');
    return Scaffold(
      appBar: AppBar(title: const Text('Review receipt')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (path != null && !isPdf && File(path).existsSync())
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(File(path), height: 180, fit: BoxFit.cover),
              ),
            ),
          if (isPdf)
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text('A PDF is attached to this receipt.'),
            ),
          if (note != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                note,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          TextField(
            key: const Key('merchant-field'),
            controller: _merchant,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Merchant',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Purchase date'),
            subtitle: Text(formatDate(_date)),
            trailing: const Icon(Icons.calendar_today),
            onTap: _pickDate,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('total-field'),
                  controller: _total,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Total',
                    hintText: 'e.g. 70.60, RM20,000.40',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 120,
                child: TextField(
                  key: const Key('currency-field'),
                  controller: _currency,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Currency',
                    hintText: 'NZD',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _number,
            decoration: const InputDecoration(
              labelText: 'Receipt number',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(
              labelText: 'Category',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final category in receiptCategories)
                DropdownMenuItem(value: category, child: Text(category)),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _category = value);
              }
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _usage,
            decoration: const InputDecoration(
              labelText: 'Use',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final usage in receiptUses)
                DropdownMenuItem(value: usage, child: Text(usageLabel(usage))),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _usage = value);
              }
            },
          ),
          if (_usage == 'mixed') ...[
            const SizedBox(height: 16),
            const Text('Business items'),
            for (var index = 0; index < _items.length; index++) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _items[index].description,
                      decoration: const InputDecoration(
                        labelText: 'Item',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 110,
                    child: TextField(
                      controller: _items[index].amount,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remove item',
                    onPressed: () {
                      setState(() {
                        _items.removeAt(index).dispose();
                      });
                    },
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ],
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() => _items.add(_ItemFields())),
                child: const Text('Add business item'),
              ),
            ),
          ],
          if (_usage != 'personal') ...[
            const SizedBox(height: 12),
            TextField(
              controller: _gstShown,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'GST shown',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _gstClaim,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'GST to claim',
                border: OutlineInputBorder(),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Needs review'),
              value: _gstNeedsReview,
              onChanged: (value) => setState(() => _gstNeedsReview = value),
            ),
          ],
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 20),
          FilledButton(
            key: const Key('save-receipt'),
            onPressed: _save,
            child: const Text('Save receipt'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() => _date = _dateOnly(picked));
    }
  }

  Future<void> _save() async {
    final merchant = _merchant.text.trim();
    final cents = parseMoney(_total.text);
    if (merchant.isEmpty || cents == null) {
      setState(() => _error = 'Enter a merchant and a total such as 18.50.');
      return;
    }
    final items = <ReceiptItem>[];
    if (_usage == 'mixed') {
      for (final fields in _items) {
        final description = fields.description.text.trim();
        final amount = parseMoney(fields.amount.text);
        if (description.isEmpty && fields.amount.text.trim().isEmpty) {
          continue;
        }
        if (description.isEmpty || amount == null) {
          setState(
            () => _error = 'Each business item needs a name and an amount.',
          );
          return;
        }
        items.add(ReceiptItem(description: description, amountCents: amount));
      }
      final itemError = validateMixedItems(
        usage: _usage,
        totalCents: cents,
        items: items,
      );
      if (itemError != null) {
        setState(() => _error = itemError);
        return;
      }
    }
    int? gstShown;
    int? gstClaim;
    if (_usage != 'personal') {
      final shownText = _gstShown.text.trim();
      final claimText = _gstClaim.text.trim();
      if (shownText.isNotEmpty) {
        gstShown = parseMoney(shownText);
        if (gstShown == null) {
          setState(() => _error = 'Enter GST shown as an amount such as 2.41.');
          return;
        }
      }
      if (claimText.isNotEmpty) {
        gstClaim = parseMoney(claimText);
        if (gstClaim == null) {
          setState(
            () => _error = 'Enter GST to claim as an amount such as 2.41.',
          );
          return;
        }
      }
    }
    final similar = widget.store.similarTo(_date, cents);
    if (similar != null && mounted) {
      final saveAnyway = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Possible duplicate'),
            content: Text(
              'This looks similar to ${similar.merchant} on ${formatDate(similar.purchasedOn)} (\$${formatMoney(similar.totalCents)}).',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Go back'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Save anyway'),
              ),
            ],
          );
        },
      );
      if (saveAnyway != true || !mounted) {
        return;
      }
    }
    final number = _number.text.trim();
    final typedCurrency = _currency.text.trim().toUpperCase();
    final resolvedCurrency = typedCurrency.isNotEmpty
        ? (detectCurrency(typedCurrency) ?? typedCurrency)
        : detectCurrency(_total.text);
    Navigator.pop(
      context,
      Receipt(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        merchant: merchant,
        purchasedOn: _date,
        totalCents: cents,
        category: _category,
        currency: resolvedCurrency,
        receiptNumber: number.isEmpty ? null : number,
        fileSha256: widget.draft.fileSha256,
        localFilePath: widget.draft.localFilePath,
        extractionSource: widget.draft.extractionSource,
        usage: _usage,
        items: items,
        gstShownCents: gstShown,
        gstClaimCents: gstClaim,
        gstNeedsReview: _usage != 'personal' && _gstNeedsReview,
      ),
    );
  }
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);
