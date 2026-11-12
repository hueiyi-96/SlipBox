import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'local_scan.dart';

class MlKitReceiptTextReader implements ReceiptTextReader {
  @override
  Future<List<ScanLine>> read(String path) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final recognized = await recognizer.processImage(
        InputImage.fromFilePath(path),
      );
      final lines = <ScanLine>[];
      for (final block in recognized.blocks) {
        for (final line in block.lines) {
          lines.add(ScanLine(line.text, line.boundingBox.top.toDouble()));
        }
      }
      return lines;
    } finally {
      await recognizer.close();
    }
  }
}
