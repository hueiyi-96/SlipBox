import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class CapturedReceipt {
  const CapturedReceipt({
    required this.path,
    required this.sha256,
    required this.bytes,
  });

  final String path;
  final String sha256;
  final List<int> bytes;
}

class ReceiptCapture {
  ReceiptCapture({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  Future<CapturedReceipt?> takePhoto() {
    return _pick(ImageSource.camera);
  }

  Future<CapturedReceipt?> choosePhoto() {
    return _pick(ImageSource.gallery);
  }

  Future<CapturedReceipt?> _pick(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 1800,
      imageQuality: 80,
    );
    if (picked == null) {
      return null;
    }
    final bytes = await picked.readAsBytes();
    final digest = sha256.convert(bytes).toString();
    final directory = await getApplicationDocumentsDirectory();
    final folder = Directory('${directory.path}/receipts');
    await folder.create(recursive: true);
    final file = File('${folder.path}/$digest.jpg');
    if (!await file.exists()) {
      await file.writeAsBytes(bytes, flush: true);
    }
    return CapturedReceipt(path: file.path, sha256: digest, bytes: bytes);
  }
}
