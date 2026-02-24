import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:scanner_carnetizacion/firebase_options.dart';
import 'providers/scanner_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => ScannerProvider())],
      child: const MaterialApp(
        home: ScannerScreen(),
        debugShowCheckedModeBanner: false,
      ),
    ),
  );
}

class ScannerScreen extends StatelessWidget {
  const ScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScannerProvider>();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(
            onDetect: (capture) {
              if (capture.barcodes.isNotEmpty &&
                  capture.barcodes.first.rawValue != null) {
                provider.validarQrCode(capture.barcodes.first.rawValue!);
              }
            },
          ),
          // Un pequeño aviso visual para el guardia
          if (provider.isProcessing)
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 50),
              ),
            ),
        ],
      ),
    );
  }
}
