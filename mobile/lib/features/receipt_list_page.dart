import 'package:flutter/material.dart';

import 'local_scan.dart';
import 'receipt.dart';
import 'receipt_capture.dart';
import 'receipt_detail_page.dart';
import 'receipt_form_page.dart';
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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('TracePay')),
      body: ListenableBuilder(
        listenable: widget.store,
        builder: (context, _) {
          final receipts = widget.store.receipts;
          if (receipts.isEmpty) {
            return const Center(child: Text('No receipts yet'));
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
    await _scan(choice == 'camera');
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
