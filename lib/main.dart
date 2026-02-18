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
// ==========================================
// PANTALLA DE RESULTADOS (Responsiva y Dinámica)
// ==========================================
class ResultScreen extends StatelessWidget {
  final VoidCallback onScanAgain;

  const ResultScreen({super.key, required this.onScanAgain});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScannerProvider>();
    final state = provider.state;
    final persona = provider.personaEncontrada;

    // Obtenemos el tamaño exacto de la pantalla del celular
    final size = MediaQuery.of(context).size;

    // Variables de diseño por defecto
    Color bgColor = const Color(0xFFFFD54F); // Amarillo
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
            SizedBox(height: size.height * 0.02), // 2% de la pantalla
            // Badge "SESIÓN ACTIVA"
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
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
            SizedBox(height: size.height * 0.03),

            // Icono Dinámico (Se adapta al alto de la pantalla)
            Icon(
              mainIcon,
              size: size.height * 0.1,
              color: const Color(0xFF1E293B),
            ),
            SizedBox(height: size.height * 0.01),

            // Título Dinámico (Se encoge si no entra)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1E293B),
                    height: 1.1,
                  ),
                ),
              ),
            ),
            SizedBox(height: size.height * 0.03),

            // Tarjeta Blanca Inferior (¡AHORA ES SCROLLABLE!)
            Expanded(
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(
                  size.width * 0.07,
                ), // Padding relativo al ancho
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(40),
                    topRight: Radius.circular(40),
                  ),
                ),
                // Aquí metemos el SingleChildScrollView para evitar recortes
                child: persona != null
                    ? SingleChildScrollView(
                        child: _buildPersonaInfo(persona, size),
                      )
                    : _buildErrorMessage(provider.errorMessage),
              ),
            ),

            // Botón de Escanear de Nuevo
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

  // --- WIDGET: DATOS DE LA PERSONA (RESPONSIVO) ---
  Widget _buildPersonaInfo(Map<String, dynamic> persona, Size size) {
    // 1. Armar nombre completo
    final nombreCompleto =
        "${persona['nombre']} ${persona['apellidoPaterno']} ${persona['apellidoMaterno'] ?? ''}"
            .trim();

    // 2. ¡CORRECCIÓN DE IMAGEN! Usamos el campo directo del JSON
    final String photoUrl =
        (persona['imagen'] != null && persona['imagen'].toString().isNotEmpty)
        ? persona['imagen'] // URL directa de tu base de datos
        : 'https://ui-avatars.com/api/?name=${persona['nombre']}+${persona['apellidoPaterno']}&background=random&color=fff';

    // 3. Obtener hora actual en formato HH:MM
    final horaIngreso =
        "${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}";

    return Column(
      mainAxisSize: MainAxisSize.min, // Que ocupe solo lo necesario
      children: [
        // Foto circular adaptativa
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.amber, width: 4),
          ),
          child: CircleAvatar(
            radius: size.height * 0.08, // El radio es el 8% de la pantalla
            backgroundImage: NetworkImage(photoUrl),
            backgroundColor: Colors.grey.shade200,
          ),
        ),
        SizedBox(height: size.height * 0.02),

        // Nombre
        const Text(
          "NOMBRE COMPLETO",
          style: TextStyle(
            color: Colors.grey,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 5),
        // FittedBox evita que nombres muy largos (ej. 4 nombres) se salgan de la pantalla
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            nombreCompleto,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1E293B),
            ),
          ),
        ),
        SizedBox(height: size.height * 0.02),

        // Carnet
        const Text(
          "CARNET DE IDENTIDAD",
          style: TextStyle(
            color: Colors.grey,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          "${persona['carnetIdentidad']}",
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),

        Padding(
          padding: EdgeInsets.symmetric(vertical: size.height * 0.02),
          child: const Divider(),
        ),

        // Fila Inferior (Hora y Departamento)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Flexible(
              child: Column(
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
            ),
            Flexible(
              child: Column(
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
                    // FittedBox para departamentos con nombres eternos
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        "${persona['unidad'] ?? 'Sin unidad'}",
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
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
