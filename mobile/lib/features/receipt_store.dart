import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'receipt.dart';

class ReceiptStore extends ChangeNotifier {
  final List<Receipt> _items = [];

  List<Receipt> get receipts => List.unmodifiable(_items);

  void add(Receipt receipt) {
    _items.add(receipt);
    _items.sort((a, b) => b.purchasedOn.compareTo(a.purchasedOn));
    notifyListeners();
    unawaited(persist());
  }

  bool hasHash(String sha256) {
    return _items.any((receipt) => receipt.fileSha256 == sha256);
  }

  Receipt? similarTo(DateTime day, int totalCents) {
    for (final receipt in _items) {
      final sameDay =
          receipt.purchasedOn.year == day.year &&
          receipt.purchasedOn.month == day.month &&
          receipt.purchasedOn.day == day.day;
      if (sameDay && receipt.totalCents == totalCents) {
        return receipt;
      }
    }
    return null;
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
        if (item is Map) Receipt.fromJson(Map<String, Object?>.from(item)),
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
