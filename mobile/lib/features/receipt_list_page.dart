import 'package:flutter/material.dart';

import 'category_page.dart';
import 'export_page.dart';
import 'local_scan.dart';
import 'receipt.dart';
import 'receipt_capture.dart';
import 'receipt_detail_page.dart';
import 'receipt_form_page.dart';
import 'receipt_records.dart';
import 'receipt_store.dart';

class ReceiptListPage extends StatefulWidget {
  const ReceiptListPage({
    super.key,
    required this.store,
    required this.capture,
    required this.coordinator,
  });

  final ReceiptStore store;
  final ReceiptCapture capture;
  final ScanCoordinator coordinator;

  @override
  State<ReceiptListPage> createState() => _ReceiptListPageState();
}

class _ReceiptListPageState extends State<ReceiptListPage> {
  String _query = '';
  DateTime? _from;
  DateTime? _to;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TracePay'),
        actions: [
          IconButton(
            tooltip: 'Spending',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (context) => CategoryPage(store: widget.store),
                ),
              );
            },
            icon: const Icon(Icons.pie_chart_outline),
          ),
          IconButton(
            tooltip: 'Export',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (context) => ExportPage(store: widget.store),
                ),
              );
            },
            icon: const Icon(Icons.ios_share),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: widget.store,
        builder: (context, _) {
          final receipts = findReceipts(
            widget.store.receipts,
            query: _query,
            from: _from,
            to: _to,
          );
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: TextField(
                  key: const Key('search-receipts'),
                  decoration: const InputDecoration(
                    hintText: 'Merchant or receipt number',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
              ListTile(
                dense: true,
                title: Text(
                  _from == null || _to == null
                      ? 'All dates'
                      : '${formatDate(_from!)} – ${formatDate(_to!)}',
                ),
                trailing: TextButton(
                  onPressed: _pickDates,
                  child: Text(_from == null ? 'Choose dates' : 'Change dates'),
                ),
              ),
              Expanded(
                child: receipts.isEmpty
                    ? Center(
                        child: Text(
                          widget.store.receipts.isEmpty
                              ? 'No receipts yet'
                              : 'No matching receipts',
                        ),
                      )
                    : ListView.separated(
                        itemCount: receipts.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final receipt = receipts[index];
                          final review = receipt.gstNeedsReview
                              ? ' · Needs review'
                              : '';
                          return ListTile(
                            title: Text(receipt.merchant),
                            subtitle: Text(
                              '${formatDate(receipt.purchasedOn)} · ${receipt.category} · ${usageLabel(receipt.usage)}$review',
                            ),
                            trailing: Text(
                              '\$${formatMoney(receipt.totalCents)}',
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (context) =>
                                      ReceiptDetailPage(receipt: receipt),
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('add-receipt'),
        tooltip: 'Add receipt',
        onPressed: _chooseHowToAdd,
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _chooseHowToAdd() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Take photo'),
                onTap: () => Navigator.pop(context, 'camera'),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose photo'),
                onTap: () => Navigator.pop(context, 'gallery'),
              ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf),
                title: const Text('Choose PDF'),
                onTap: () => Navigator.pop(context, 'pdf'),
              ),
              ListTile(
                key: const Key('enter-details'),
                leading: const Icon(Icons.edit),
                title: const Text('Enter details'),
                onTap: () => Navigator.pop(context, 'manual'),
              ),
            ],
          ),
        );
      },
    );
    if (!mounted || choice == null) {
      return;
    }
    if (choice == 'manual') {
      await _openForm(ReceiptDraft(purchasedOn: DateTime.now()));
      return;
    }
    if (choice == 'pdf') {
      await _attachPdf();
      return;
    }
    await _scan(choice == 'camera');
  }

  Future<void> _pickDates() async {
    final from = await showDatePicker(
      context: context,
      initialDate: _from ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (from == null || !mounted) {
      return;
    }
    final to = await showDatePicker(
      context: context,
      initialDate: _to ?? from,
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

  Future<void> _attachPdf() async {
    try {
      final captured = await widget.capture.choosePdf();
      if (!mounted || captured == null) {
        return;
      }
      if (widget.store.hasHash(captured.sha256)) {
        _message('This receipt file is already saved.');
        return;
      }
      await _openForm(
        ReceiptDraft(
          purchasedOn: DateTime.now(),
          localFilePath: captured.path,
          fileSha256: captured.sha256,
          note: 'Enter the details from this PDF.',
        ),
      );
    } catch (_) {
      if (mounted) {
        _message('The PDF could not be opened.');
      }
    }
  }

  Future<void> _scan(bool camera) async {
    var reading = false;
    try {
      final captured = camera
          ? await widget.capture.takePhoto()
          : await widget.capture.choosePhoto();
      if (!mounted || captured == null) {
        return;
      }
      if (widget.store.hasHash(captured.sha256)) {
        _message('This receipt file is already saved.');
        return;
      }
      if (!mounted) {
        return;
      }
      reading = true;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
      final draft = await widget.coordinator.fromImage(
        path: captured.path,
        bytes: captured.bytes,
        sha256: captured.sha256,
      );
      if (!mounted) {
        return;
      }
      reading = false;
      Navigator.pop(context);
      await _openForm(draft);
    } catch (_) {
      if (!mounted) {
        return;
      }
      if (reading) {
        Navigator.pop(context);
      }
      _message('The photo could not be read. Enter the details instead.');
    }
  }

  Future<void> _openForm(ReceiptDraft draft) async {
    final receipt = await Navigator.push<Receipt>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ReceiptFormPage(store: widget.store, draft: draft),
      ),
    );
    if (receipt != null) {
      widget.store.add(receipt);
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}
