import 'dart:io';

import 'package:flutter/material.dart';

import 'local_scan.dart';
import 'receipt.dart';
import 'receipt_store.dart';

class ReceiptFormPage extends StatefulWidget {
  const ReceiptFormPage({super.key, required this.store, required this.draft});

  final ReceiptStore store;
  final ReceiptDraft draft;

  @override
  State<ReceiptFormPage> createState() => _ReceiptFormPageState();
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
  late final TextEditingController _number = TextEditingController(
    text: widget.draft.receiptNumber ?? '',
  );
  late DateTime _date = _dateOnly(widget.draft.purchasedOn ?? DateTime.now());
  String _category = receiptCategories.first;
  String? _error;

  @override
  void dispose() {
    _merchant.dispose();
    _total.dispose();
    _number.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final path = widget.draft.localFilePath;
    final note = widget.draft.note;
    return Scaffold(
      appBar: AppBar(title: const Text('Review receipt')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (path != null && File(path).existsSync())
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(File(path), height: 180, fit: BoxFit.cover),
              ),
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
          TextField(
            key: const Key('total-field'),
            controller: _total,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Total',
              border: OutlineInputBorder(),
            ),
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
    Navigator.pop(
      context,
      Receipt(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        merchant: merchant,
        purchasedOn: _date,
        totalCents: cents,
        category: _category,
        receiptNumber: number.isEmpty ? null : number,
        fileSha256: widget.draft.fileSha256,
        localFilePath: widget.draft.localFilePath,
        extractionSource: widget.draft.extractionSource,
      ),
    );
  }
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);
