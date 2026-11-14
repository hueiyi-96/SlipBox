class ReceiptItem {
  const ReceiptItem({required this.description, required this.amountCents});

  final String description;
  final int amountCents;

  Map<String, Object?> toJson() {
    return {'description': description, 'amountCents': amountCents};
  }

  factory ReceiptItem.fromJson(Map<String, Object?> json) {
    return ReceiptItem(
      description: json['description']! as String,
      amountCents: json['amountCents']! as int,
    );
  }
}

class Receipt {
  const Receipt({
    required this.id,
    required this.merchant,
    required this.purchasedOn,
    required this.totalCents,
    required this.category,
    this.currency,
    this.receiptNumber,
    this.fileSha256,
    this.localFilePath,
    this.extractionSource = 'manual',
    this.usage = 'personal',
    this.items = const [],
    this.gstShownCents,
    this.gstClaimCents,
    this.gstNeedsReview = false,
  });

  final String id;
  final String merchant;
  final DateTime purchasedOn;
  final int totalCents;
  final String category;
  final String? currency;
  final String? receiptNumber;
  final String? fileSha256;
  final String? localFilePath;

  /// manual, local_mlkit, or cloud_ocr.
  final String extractionSource;

  /// personal, business, or mixed.
  final String usage;
  final List<ReceiptItem> items;
  final int? gstShownCents;
  final int? gstClaimCents;
  final bool gstNeedsReview;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'merchant': merchant,
      'purchasedOn': purchasedOn.toIso8601String(),
      'totalCents': totalCents,
      'category': category,
      'currency': currency,
      'receiptNumber': receiptNumber,
      'fileSha256': fileSha256,
      'localFilePath': localFilePath,
      'extractionSource': extractionSource,
      'usage': usage,
      'items': [for (final item in items) item.toJson()],
      'gstShownCents': gstShownCents,
      'gstClaimCents': gstClaimCents,
      'gstNeedsReview': gstNeedsReview,
    };
  }

  factory Receipt.fromJson(Map<String, Object?> json) {
    return Receipt(
      id: json['id']! as String,
      merchant: json['merchant']! as String,
      purchasedOn: DateTime.parse(json['purchasedOn']! as String),
      totalCents: json['totalCents']! as int,
      category: json['category']! as String,
      currency: json['currency'] as String?,
      receiptNumber: json['receiptNumber'] as String?,
      fileSha256: json['fileSha256'] as String?,
      localFilePath: json['localFilePath'] as String?,
      extractionSource: json['extractionSource'] as String? ?? 'manual',
      usage: json['usage'] as String? ?? 'personal',
      items: [
        for (final item in json['items'] as List? ?? const [])
          if (item is Map)
            ReceiptItem.fromJson(Map<String, Object?>.from(item)),
      ],
      gstShownCents: json['gstShownCents'] as int?,
      gstClaimCents: json['gstClaimCents'] as int?,
      gstNeedsReview: json['gstNeedsReview'] as bool? ?? false,
    );
  }
}

const receiptUses = ['personal', 'business', 'mixed'];

String usageLabel(String usage) {
  switch (usage) {
    case 'business':
      return 'Business';
    case 'mixed':
      return 'Mixed';
    default:
      return 'Personal';
  }
}

int businessCents(Receipt receipt) {
  switch (receipt.usage) {
    case 'business':
      return receipt.totalCents;
    case 'mixed':
      return receipt.items.fold(0, (sum, item) => sum + item.amountCents);
    default:
      return 0;
  }
}

const receiptCategories = [
  'Food',
  'Transport',
  'Supplies',
  'Utilities',
  'Other',
];

String formatMoney(int cents) {
  final sign = cents < 0 ? '-' : '';
  final absolute = cents.abs();
  final dollars = absolute ~/ 100;
  final remainder = (absolute % 100).toString().padLeft(2, '0');
  return '$sign$dollars.$remainder';
}

String formatReceiptMoney(int cents, {String? currency}) {
  final code = currency?.trim().toUpperCase();
  if (code != null && code.isNotEmpty) {
    return '$code ${formatMoney(cents)}';
  }
  return '\$${formatMoney(cents)}';
}

/// Parses amounts such as `18.50`, `NZD70.60`, `RM20,000.40`, `20.000,40`,
/// `70,60`, or `25,000` into integer cents.
int? parseMoney(String raw) {
  final stripped = raw
      .trim()
      .replaceFirst(RegExp(r'^(?:[A-Za-z]{1,3}\$?|[$€£¥])\s*'), '')
      .replaceFirst(RegExp(r'\s*(?:[A-Za-z]{1,3}\$?|[$€£¥])$'), '')
      .trim();
  if (stripped.isEmpty) {
    return null;
  }
  final compact = stripped.replaceAllMapped(
    RegExp(r'(?<=\d) (?=\d{3}(?:[ ,.]|$))'),
    (_) => '',
  );
  return parseMoneyToken(compact);
}

int? parseMoneyToken(String token) {
  if (!RegExp(r'^\d(?:[\d.,]*\d)?$').hasMatch(token)) {
    return null;
  }
  final hasDot = token.contains('.');
  final hasComma = token.contains(',');
  if (!hasDot && !hasComma) {
    return int.parse(token) * 100;
  }
  if (hasDot && hasComma) {
    final lastDot = token.lastIndexOf('.');
    final lastComma = token.lastIndexOf(',');
    final decSep = lastDot > lastComma ? '.' : ',';
    final thouSep = decSep == '.' ? ',' : '.';
    if (token.indexOf(decSep) != token.lastIndexOf(decSep)) {
      return null;
    }
    final parts = token.split(decSep);
    final whole = parts[0];
    final fraction = parts[1];
    final thouPattern = RegExp('^\\d{1,3}(?:\\$thouSep\\d{3})+\$');
    if (!thouPattern.hasMatch(whole) ||
        !RegExp(r'^\d{1,2}$').hasMatch(fraction)) {
      return null;
    }
    final dollars = int.parse(whole.replaceAll(thouSep, ''));
    final cents = int.parse(fraction.padRight(2, '0'));
    return dollars * 100 + cents;
  }

  final sep = hasDot ? '.' : ',';
  final parts = token.split(sep);
  if (parts.length > 2) {
    final thouPattern = RegExp('^\\d{1,3}(?:\\$sep\\d{3})+\$');
    if (!thouPattern.hasMatch(token)) {
      return null;
    }
    return int.parse(parts.join()) * 100;
  }

  final left = parts[0];
  final right = parts[1];
  if (!RegExp(r'^\d+$').hasMatch(left) || !RegExp(r'^\d+$').hasMatch(right)) {
    return null;
  }
  if (right.length <= 2) {
    return int.parse(left) * 100 + int.parse(right.padRight(2, '0'));
  }
  if (right.length == 3 && left.length <= 3 && !left.startsWith('0')) {
    return int.parse('$left$right') * 100;
  }
  return null;
}

const _isoCurrencies = {
  'NZD',
  'MYR',
  'AUD',
  'USD',
  'SGD',
  'EUR',
  'GBP',
  'CAD',
  'IQD',
  'IDR',
  'PHP',
  'THB',
  'HKD',
  'CNY',
};

String? detectCurrency(String text) {
  if (text.contains('€')) {
    return 'EUR';
  }
  if (text.contains('£')) {
    return 'GBP';
  }
  final symbolMatch = RegExp(
    r'(?<![A-Za-z])(NZ\$|AU\$|A\$|US\$|SG\$|S\$|HK\$)',
    caseSensitive: false,
  ).firstMatch(text);
  if (symbolMatch != null) {
    switch (symbolMatch.group(1)!.toUpperCase()) {
      case 'NZ\$':
        return 'NZD';
      case 'AU\$':
      case 'A\$':
        return 'AUD';
      case 'US\$':
        return 'USD';
      case 'SG\$':
      case 'S\$':
        return 'SGD';
      case 'HK\$':
        return 'HKD';
    }
  }
  final rmMatch = RegExp(
    r'(?<![A-Za-z])RM(?=\s*\d)',
    caseSensitive: false,
  ).firstMatch(text);
  if (rmMatch != null) {
    return 'MYR';
  }
  final codeMatches = RegExp(r'(?<![A-Za-z])([A-Za-z]{3})(?![A-Za-z])')
      .allMatches(text);
  for (final match in codeMatches) {
    final upper = match.group(1)!.toUpperCase();
    if (upper == 'RMB') {
      return 'CNY';
    }
    if (_isoCurrencies.contains(upper)) {
      return upper;
    }
  }
  return null;
}

String formatDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}
