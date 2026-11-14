import '../core/errors.dart';
import '../core/network.dart';
import 'receipt.dart';

class ScanLine {
  const ScanLine(this.text, this.top);

  final String text;
  final double top;
}

class LocalScanResult {
  const LocalScanResult({
    this.merchant,
    this.purchasedOn,
    this.totalCents,
    this.currency,
  });

  final String? merchant;
  final DateTime? purchasedOn;
  final int? totalCents;
  final String? currency;

  bool get isComplete =>
      merchant != null && purchasedOn != null && totalCents != null;
}

class ReceiptDraft {
  const ReceiptDraft({
    this.merchant,
    this.purchasedOn,
    this.totalCents,
    this.currency,
    this.receiptNumber,
    this.localFilePath,
    this.fileSha256,
    this.extractionSource = 'manual',
    this.note,
  });

  final String? merchant;
  final DateTime? purchasedOn;
  final int? totalCents;
  final String? currency;
  final String? receiptNumber;
  final String? localFilePath;
  final String? fileSha256;
  final String extractionSource;
  final String? note;
}

abstract class ReceiptTextReader {
  Future<List<ScanLine>> read(String path);
}

class ScanCoordinator {
  ScanCoordinator({required this.textReader, this.extractionApi});

  final ReceiptTextReader textReader;
  final ReceiptExtractionApi? extractionApi;

  Future<ReceiptDraft> fromImage({
    required String path,
    required List<int> bytes,
    required String sha256,
  }) async {
    final local = readReceiptText(await textReader.read(path));
    if (local.isComplete) {
      return ReceiptDraft(
        merchant: local.merchant,
        purchasedOn: local.purchasedOn,
        totalCents: local.totalCents,
        currency: local.currency,
        localFilePath: path,
        fileSha256: sha256,
        extractionSource: 'local_mlkit',
      );
    }

    var merchant = local.merchant;
    var purchasedOn = local.purchasedOn;
    var totalCents = local.totalCents;
    var currency = local.currency;
    String? receiptNumber;
    var source = 'local_mlkit';
    String? note;

    final api = extractionApi;
    if (api != null) {
      try {
        final remote = await api.extract(bytes, contentType: 'image/jpeg');
        merchant ??= remote.merchant;
        purchasedOn ??= remote.purchasedOn;
        totalCents ??= remote.totalCents;
        currency ??= remote.currency;
        receiptNumber = remote.receiptNumber;
        source = 'cloud_ocr';
      } on ReceiptExtractionException catch (error) {
        note = error.message;
      } catch (_) {
        note = 'The scan service could not be reached. Fill in the missing details.';
      }
    }

    final complete =
        merchant != null && purchasedOn != null && totalCents != null;
    return ReceiptDraft(
      merchant: merchant,
      purchasedOn: purchasedOn,
      totalCents: totalCents,
      currency: currency,
      receiptNumber: receiptNumber,
      localFilePath: path,
      fileSha256: sha256,
      extractionSource: source,
      note: complete
          ? null
          : (note ?? 'Check merchant, date, and total before saving.'),
    );
  }
}

LocalScanResult readReceiptText(List<ScanLine> lines) {
  final ordered = [...lines]..sort((a, b) => a.top.compareTo(b.top));
  return LocalScanResult(
    merchant: _merchant(ordered),
    purchasedOn: _date(ordered),
    totalCents: _total(ordered),
    currency: _currency(ordered),
  );
}

const _skipLine = {
  'tax invoice',
  'invoice',
  'receipt',
  'tax receipt',
  'eftpos',
  'customer copy',
  'merchant copy',
  'gst',
  'abn',
  'welcome',
  'thank you',
};

String? _merchant(List<ScanLine> lines) {
  for (final line in lines) {
    final text = line.text.trim();
    if (text.length < 3) {
      continue;
    }
    if (_skipLine.contains(text.toLowerCase())) {
      continue;
    }
    if (RegExp(r'^[\d\s./\$-]+$').hasMatch(text)) {
      continue;
    }
    if (_findDate(text) != null && !RegExp(r'[A-Za-z]{3,}').hasMatch(text)) {
      continue;
    }
    return text;
  }
  return null;
}

DateTime? _date(List<ScanLine> lines) {
  for (final line in lines) {
    final found = _findDate(line.text);
    if (found != null) {
      return found;
    }
  }
  return null;
}

int? _total(List<ScanLine> lines) {
  for (final line in lines.reversed) {
    final lower = line.text.toLowerCase();
    if (lower.contains('subtotal') ||
        lower.contains('sub-total') ||
        lower.contains('sub total')) {
      continue;
    }
    if (!RegExp(r'\b(total|amount due|balance due)\b').hasMatch(lower)) {
      continue;
    }
    final cents = _lastMoney(line.text);
    if (cents != null) {
      return cents;
    }
  }
  return null;
}

int? _lastMoney(String text) {
  final compact = text.replaceAllMapped(
    RegExp(r'(?<=\d) (?=\d{3}(?:[ ,.]|$))'),
    (_) => '',
  );
  final matches = RegExp(
    r'(?<![\d.,])(?:\d{1,3}(?:[.,]\d{3})+[.,]\d{2}|\d+[.,]\d{2}|\d{1,3}(?:,\d{3})+)(?![\d.,])',
  ).allMatches(compact);
  int? last;
  for (final match in matches) {
    final parsed = parseMoneyToken(match.group(0)!);
    if (parsed != null) {
      last = parsed;
    }
  }
  return last;
}

String? _currency(List<ScanLine> lines) {
  for (final line in lines.reversed) {
    final lower = line.text.toLowerCase();
    if (RegExp(r'\b(total|amount due|balance due)\b').hasMatch(lower)) {
      final found = detectCurrency(line.text);
      if (found != null) {
        return found;
      }
    }
  }
  for (final line in lines) {
    final found = detectCurrency(line.text);
    if (found != null) {
      return found;
    }
  }
  return null;
}

final _months = {
  'jan': 1,
  'feb': 2,
  'mar': 3,
  'apr': 4,
  'may': 5,
  'jun': 6,
  'jul': 7,
  'aug': 8,
  'sep': 9,
  'oct': 10,
  'nov': 11,
  'dec': 12,
};

DateTime? _findDate(String text) {
  final iso = RegExp(r'\b(\d{4})-(\d{2})-(\d{2})\b').firstMatch(text);
  if (iso != null) {
    return _validDate(
      int.parse(iso.group(1)!),
      int.parse(iso.group(2)!),
      int.parse(iso.group(3)!),
    );
  }

  final named = RegExp(
    r'\b(\d{1,2})\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+(\d{4})\b',
    caseSensitive: false,
  ).firstMatch(text);
  if (named != null) {
    return _validDate(
      int.parse(named.group(3)!),
      _months[named.group(2)!.substring(0, 3).toLowerCase()]!,
      int.parse(named.group(1)!),
    );
  }

  final numeric = RegExp(r'\b(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})\b')
      .firstMatch(text);
  if (numeric != null) {
    var year = int.parse(numeric.group(3)!);
    if (year < 100) {
      year += 2000;
    }
    return _validDate(
      year,
      int.parse(numeric.group(2)!),
      int.parse(numeric.group(1)!),
    );
  }
  return null;
}

DateTime? _validDate(int year, int month, int day) {
  if (month < 1 || month > 12 || day < 1 || day > 31) {
    return null;
  }
  final date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) {
    return null;
  }
  final today = DateTime.now();
  final newest = DateTime(
    today.year,
    today.month,
    today.day,
  ).add(const Duration(days: 1));
  if (date.isBefore(DateTime(2000)) || date.isAfter(newest)) {
    return null;
  }
  return date;
}
