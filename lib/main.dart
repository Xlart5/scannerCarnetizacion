import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'providers/scanner_provider.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => ScannerProvider())],
      child: const ScannerApp(),
    ),
  );
}

class ScannerApp extends StatelessWidget {
  const ScannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Escáner de Acceso',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const ScannerScreen(),
    );
  }
}

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  // Controlador para la cámara
  MobileScannerController cameraController = MobileScannerController();
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScannerProvider>();

    // Si estamos cargando, o mostrando un resultado, ocultamos la cámara
    if (provider.state != ScannerState.idle) {
      return ResultScreen(
        onScanAgain: () {
          _isProcessing = false;
          cameraController.start(); // Reactivamos cámara
          provider.resetScanner();
        },
      );
    }

    // PANTALLA PRINCIPAL: LA CÁMARA
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(
            controller: cameraController,
            onDetect: (capture) async {
              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isEmpty || _isProcessing) return;

              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  setState(() => _isProcessing = true);
                  cameraController.stop(); // Pausamos la cámara al detectar

                  // Llamamos al provider con el String del QR
                  await provider.validarQrCode(barcode.rawValue!);
                }
              }
            },
          ),
          // Diseño superpuesto (el marco y el texto)
          _buildOverlay(),
        ],
      ),
    );
  }

  Widget _buildOverlay() {
    return SafeArea(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(20.0),
            child: Text(
              "Escanear QR de Acceso",
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                shadows: [Shadow(blurRadius: 10, color: Colors.black)],
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.amber, width: 4),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Center(
                  child: Icon(
                    Icons.qr_code_scanner,
                    color: Colors.white54,
                    size: 100,
                  ),
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(30.0),
            child: Text(
              "Apunte la cámara al código QR de la credencial",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// PANTALLA DE RESULTADOS (Verde o Rojo)
// ==========================================
class ResultScreen extends StatelessWidget {
  final VoidCallback onScanAgain;

  const ResultScreen({super.key, required this.onScanAgain});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScannerProvider>();
    final state = provider.state;
    final persona = provider.personaEncontrada;

    Color bgColor;
    IconData mainIcon;
    String title;
    String message;

    switch (state) {
      case ScannerState.loading:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));

      case ScannerState.success:
        bgColor = Colors.green.shade600;
        mainIcon = Icons.check_circle_outline;
        title = "ACCESO PERMITIDO";
        message =
            "La persona está autorizada para ingresar al área de cómputo.";
        break;

      case ScannerState.denied:
        bgColor = Colors.red.shade700;
        mainIcon = Icons.cancel_outlined;
        title = "ACCESO DENEGADO";
        message = "Esta persona NO tiene permisos de acceso a cómputo.";
        break;

      case ScannerState.notFound:
        bgColor = Colors.orange.shade800;
        mainIcon = Icons.person_off_outlined;
        title = "NO ENCONTRADO";
        message =
            "El carnet de identidad del QR no existe en la base de datos.";
        break;

      case ScannerState.error:
      default:
        bgColor = Colors.grey.shade800;
        mainIcon = Icons.error_outline;
        title = "ERROR DE LECTURA";
        message = provider.errorMessage;
        break;
    }

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(mainIcon, size: 100, color: Colors.white),
              const SizedBox(height: 20),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 15),
              Text(
                message,
                style: const TextStyle(fontSize: 16, color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),

              // Si hay datos de persona, los mostramos en una tarjeta
              if (persona != null)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Column(
                    children: [
                      _buildInfoRow(
                        Icons.person,
                        "${persona['nombre']} ${persona['apellidoPaterno']}",
                      ),
                      const Divider(),
                      _buildInfoRow(
                        Icons.badge,
                        "C.I.: ${persona['carnetIdentidad']}",
                      ),
                      const Divider(),
                      _buildInfoRow(
                        Icons.work,
                        persona['cargo'] ?? 'Sin cargo',
                      ),
                    ],
                  ),
                ),

              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: bgColor,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  onPressed: onScanAgain,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text(
                    "ESCANEAR OTRA VEZ",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey),
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
