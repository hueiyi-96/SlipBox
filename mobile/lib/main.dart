import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'core/config.dart';
import 'core/network.dart';
import 'features/local_scan.dart';
import 'features/receipt_capture.dart';
import 'features/receipt_list_page.dart';
import 'features/receipt_store.dart';
import 'features/receipt_text_reader.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final directory = await getApplicationDocumentsDirectory();
  final store = FileReceiptStore(File('${directory.path}/receipts.json'));
  await store.load();
  runApp(
    TracePayApp(
      store: store,
      capture: ReceiptCapture(),
      textReader: MlKitReceiptTextReader(),
    ),
  );
}

class TracePayApp extends StatelessWidget {
  const TracePayApp({
    super.key,
    required this.store,
    required this.capture,
    required this.textReader,
    this.extractionApi,
  });

  final ReceiptStore store;
  final ReceiptCapture capture;
  final ReceiptTextReader textReader;
  final ReceiptExtractionApi? extractionApi;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TracePay',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1B6B4A)),
        useMaterial3: true,
      ),
      home: ReceiptListPage(
        store: store,
        capture: capture,
        coordinator: ScanCoordinator(
          textReader: textReader,
          extractionApi:
              extractionApi ??
              ReceiptExtractionApi(config: TracePayConfig.local),
        ),
      ),
    );
  }
}
