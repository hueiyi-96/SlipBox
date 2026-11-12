class TracePayException implements Exception {
  const TracePayException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ReceiptExtractionException extends TracePayException {
  const ReceiptExtractionException(super.message, {this.fileKey});

  final String? fileKey;
}
