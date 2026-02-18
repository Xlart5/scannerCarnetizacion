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
// ==========================================
// PANTALLA DE RESULTADOS (Tu Diseño Original)
// ==========================================
class ResultScreen extends StatelessWidget {
  final VoidCallback onScanAgain;

  const ResultScreen({super.key, required this.onScanAgain});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScannerProvider>();
    final state = provider.state;
    final persona = provider.personaEncontrada;

    // Variables de diseño por defecto
    Color bgColor = const Color(0xFFFFD54F); // Amarillo de tu diseño
    IconData mainIcon = Icons.verified_user;
    String title = "ACCESO\nPERMITIDO";

    // Cambiamos colores según el estado
    if (state == ScannerState.loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF1E293B),
        body: Center(child: CircularProgressIndicator(color: Colors.amber)),
      );
    } else if (state == ScannerState.denied) {
      bgColor = Colors.redAccent;
      mainIcon = Icons.cancel;
      title = "ACCESO\nDENEGADO";
    } else if (state == ScannerState.notFound) {
      bgColor = Colors.orangeAccent;
      mainIcon = Icons.person_off;
      title = "QR NO\nENCONTRADO";
    } else if (state == ScannerState.error) {
      bgColor = Colors.grey.shade800;
      mainIcon = Icons.error;
      title = "ERROR DE\nLECTURA";
    }

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Badge "SESIÓN ACTIVA"
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B), // Azul oscuro
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, color: Colors.greenAccent, size: 10),
                  SizedBox(width: 8),
                  Text(
                    "SESIÓN ACTIVA",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // Icono del Escudo
            Icon(mainIcon, size: 90, color: const Color(0xFF1E293B)),
            const SizedBox(height: 10),

            // Título
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1E293B),
                height: 1.1,
              ),
            ),
            const SizedBox(height: 30),

            // Tarjeta Blanca Inferior
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(30),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(40),
                    topRight: Radius.circular(40),
                  ),
                ),
                child: persona != null
                    ? _buildPersonaInfo(persona)
                    : _buildErrorMessage(provider.errorMessage),
              ),
            ),

            // Botón de Escanear de Nuevo (Pegado abajo en la zona blanca)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E293B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  onPressed: onScanAgain,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text(
                    "ESCANEAR OTRO QR",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGET: DATOS DE LA PERSONA ---
  Widget _buildPersonaInfo(Map<String, dynamic> persona) {
    // 1. Armar nombre completo
    final nombreCompleto =
        "${persona['nombre']} ${persona['apellidoPaterno']} ${persona['apellidoMaterno'] ?? ''}"
            .trim();

    // 2. Extraer ID de la foto para armar la URL de Ngrok
    final int? imagenId = persona['imagenId'];
    final String photoUrl = imagenId != null
        ? 'https://270d-2800-cd0-7b1c-e300-907e-f5b9-2fee-2f6e.ngrok-free.app/api/imagenes/$imagenId/descargar'
        : 'https://ui-avatars.com/api/?name=${persona['nombre']}+${persona['apellidoPaterno']}&background=random';

    // 3. Obtener hora actual en formato HH:MM
    final horaIngreso =
        "${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}";

    return Column(
      children: [
        // Foto circular con borde amarillo
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.amber, width: 4),
          ),
          child: CircleAvatar(
            radius: 60,
            backgroundImage: NetworkImage(photoUrl),
            backgroundColor: Colors.grey.shade200,
          ),
        ),
        const SizedBox(height: 25),

        // Nombre
        const Text(
          "NOMBRE COMPLETO",
          style: TextStyle(
            color: Colors.grey,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          nombreCompleto,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 20),

        // Carnet
        const Text(
          "CARNET DE IDENTIDAD",
          style: TextStyle(
            color: Colors.grey,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          "${persona['carnetIdentidad']}",
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),

        const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Divider(),
        ),

        // Fila Inferior (Hora y Departamento)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Column(
              children: [
                const Text(
                  "HORA LECTURA",
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  horaIngreso,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
            Column(
              children: [
                const Text(
                  "DEPARTAMENTO",
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    "${persona['unidad'] ?? 'Sin unidad'}",
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildErrorMessage(String error) {
    return Center(
      child: Text(
        error.isNotEmpty ? error : "No se pudo procesar la solicitud.",
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.grey, fontSize: 16),
      ),
    );
  }
}
