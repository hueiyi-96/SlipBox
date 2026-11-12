class Receipt {
  const Receipt({
    required this.id,
    required this.merchant,
    required this.purchasedOn,
    required this.totalCents,
    required this.category,
    this.receiptNumber,
    this.fileSha256,
    this.localFilePath,
    this.extractionSource = 'manual',
  });

  final String id;
  final String merchant;
  final DateTime purchasedOn;
  final int totalCents;
  final String category;
  final String? receiptNumber;
  final String? fileSha256;
  final String? localFilePath;

  /// manual, local_mlkit, or cloud_ocr.
  final String extractionSource;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'merchant': merchant,
      'purchasedOn': purchasedOn.toIso8601String(),
      'totalCents': totalCents,
      'category': category,
      'receiptNumber': receiptNumber,
      'fileSha256': fileSha256,
      'localFilePath': localFilePath,
      'extractionSource': extractionSource,
    };
  }

  factory Receipt.fromJson(Map<String, Object?> json) {
    return Receipt(
      id: json['id']! as String,
      merchant: json['merchant']! as String,
      purchasedOn: DateTime.parse(json['purchasedOn']! as String),
      totalCents: json['totalCents']! as int,
      category: json['category']! as String,
      receiptNumber: json['receiptNumber'] as String?,
      fileSha256: json['fileSha256'] as String?,
      localFilePath: json['localFilePath'] as String?,
      extractionSource: json['extractionSource'] as String? ?? 'manual',
    );
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

int? parseMoney(String raw) {
  final match = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(raw.trim());
  if (match == null) {
    return null;
  }
  final dollars = int.parse(match.group(1)!);
  final fraction = (match.group(2) ?? '').padRight(2, '0');
  final cents = fraction.isEmpty ? 0 : int.parse(fraction);
  return dollars * 100 + cents;
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
