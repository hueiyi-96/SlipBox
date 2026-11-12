import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'receipt.dart';
import 'receipt_records.dart';
import 'receipt_store.dart';

class ExportPage extends StatefulWidget {
  const ExportPage({super.key, required this.store, this.share});

  final ReceiptStore store;
  final Future<void> Function(BusinessExport export)? share;

  @override
  State<ExportPage> createState() => _ExportPageState();
}

class _ExportPageState extends State<ExportPage> {
  late DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, 1);
  late DateTime _to = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );
  String? _message;

  @override
  Widget build(BuildContext context) {
    final preview = buildBusinessExport(
      widget.store.receipts,
      from: _from,
      to: _to,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Export')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('${formatDate(_from)} – ${formatDate(_to)}'),
            trailing: const Icon(Icons.date_range),
            onTap: _pickRange,
          ),
          const SizedBox(height: 12),
          Text(preview.summary),
          if (_message != null) ...[
            const SizedBox(height: 12),
            Text(_message!),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: preview.businessTotalCents == 0 ? null : _share,
            child: const Text('Share summary and files'),
          ),
        ],
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
      _message = null;
    });
  }

  Future<void> _share() async {
    final export = buildBusinessExport(
      widget.store.receipts,
      from: _from,
      to: _to,
    );
    final sharer = widget.share ?? _shareFiles;
    await sharer(export);
    if (mounted) {
      setState(() => _message = 'Summary ready to share.');
    }
  }
}

Future<void> _shareFiles(BusinessExport export) async {
  final directory = await getTemporaryDirectory();
  final summary = File('${directory.path}/tracepay-expenses.txt');
  await summary.writeAsString(export.summary);
  final files = <XFile>[
    XFile(summary.path),
    for (final path in export.filePaths)
      if (File(path).existsSync()) XFile(path),
  ];
  await SharePlus.instance.share(ShareParams(files: files));
}
