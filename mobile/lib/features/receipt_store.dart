import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'receipt.dart';

class ReceiptStore extends ChangeNotifier {
  final List<Receipt> _items = [];

  List<Receipt> get receipts => List.unmodifiable(_items);

  void add(Receipt receipt) {
    _items.insert(0, receipt);
    notifyListeners();
    unawaited(persist());
  }

  void replaceAll(List<Receipt> receipts) {
    _items
      ..clear()
      ..addAll(receipts);
    _items.sort((a, b) => b.purchasedOn.compareTo(a.purchasedOn));
    notifyListeners();
  }

  Future<void> persist() async {}
}

class FileReceiptStore extends ReceiptStore {
  FileReceiptStore(this.file);

  final File file;

  Future<void> load() async {
    if (!await file.exists()) {
      return;
    }
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! List) {
      return;
    }
    replaceAll([
      for (final item in decoded)
        if (item is Map<String, Object?>) Receipt.fromJson(item),
    ]);
  }

  @override
  Future<void> persist() async {
    final encoded = jsonEncode([
      for (final receipt in receipts) receipt.toJson(),
    ]);
    await file.writeAsString(encoded);
  }
}
