class ExtractedReceipt {
  const ExtractedReceipt({
    required this.fileKey,
    this.merchant,
    this.purchasedOn,
    this.totalCents,
    this.taxCents,
    this.currency,
    this.receiptNumber,
  });

  final String fileKey;
  final String? merchant;
  final DateTime? purchasedOn;
  final int? totalCents;
  final int? taxCents;
  final String? currency;
  final String? receiptNumber;

  factory ExtractedReceipt.fromJson(Map<String, Object?> json) {
    final purchasedOn = json['purchasedOn'] as String?;
    return ExtractedReceipt(
      fileKey: json['fileKey']! as String,
      merchant: json['merchant'] as String?,
      purchasedOn: purchasedOn == null ? null : DateTime.parse(purchasedOn),
      totalCents: json['totalCents'] as int?,
      taxCents: json['taxCents'] as int?,
      currency: json['currency'] as String?,
      receiptNumber: json['receiptNumber'] as String?,
    );
  }
}
