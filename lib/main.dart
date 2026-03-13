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
        home: SeleccionPuertaScreen(), // Empezamos en la selección
        debugShowCheckedModeBanner: false,
      ),
    ),
  );
}

// 🔥 NUEVA PANTALLA PARA EL GUARDIA
// (Tus importaciones...)

class SeleccionPuertaScreen extends StatelessWidget {
  const SeleccionPuertaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E293B),
      appBar: AppBar(
        title: const Text("SISTEMA TED"),
        backgroundColor: Colors.black,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Seleccione su Rol",
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 40),

            // 🔥 BOTÓN 1: EXTERNOS (INGRESO)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 15,
                ),
              ),
              icon: const Icon(Icons.login, size: 30, color: Colors.white),
              label: const Text(
                "Externos - INGRESO",
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
              onPressed: () {
                context.read<ScannerProvider>().setPuerta('externos_entrada');
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ScannerScreen()),
                );
              },
            ),
            const SizedBox(height: 20),

            // 🔥 BOTÓN 2: EXTERNOS (SALIDA)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                padding: const EdgeInsets.symmetric(
                  horizontal: 45,
                  vertical: 15,
                ),
              ),
              icon: const Icon(Icons.logout, size: 30, color: Colors.white),
              label: const Text(
                "Externos - SALIDA",
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
              onPressed: () {
                context.read<ScannerProvider>().setPuerta('externos_salida');
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ScannerScreen()),
                );
              },
            ),
            const SizedBox(height: 40),
            const Divider(color: Colors.white24, indent: 50, endIndent: 50),
            const SizedBox(height: 40),

            // 🔥 BOTÓN 3: EVENTUALES
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(
                  horizontal: 55,
                  vertical: 15,
                ),
              ),
              icon: const Icon(Icons.badge, size: 30, color: Colors.white),
              label: const Text(
                "Personal EVENTUAL",
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
              onPressed: () {
                context.read<ScannerProvider>().setPuerta('eventuales');
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ScannerScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// 🔥 TU PANTALLA DEL ESCÁNER (Igual que antes)
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});
  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  void _mostrarRegistroExpress(
    BuildContext context,
    String qrCode,
    ScannerProvider provider,
  ) {
    final nombreCtrl = TextEditingController();
    final ciCtrl = TextEditingController();
    final telCtrl = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text(
          "Registrar Externo",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "QR: $qrCode",
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: nombreCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: "Nombre Completo",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: ciCtrl,
                decoration: const InputDecoration(
                  labelText: "Carnet de Identidad",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: telCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: "Teléfono Celular",
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              provider.liberarEscaner();
            },
            child: const Text("Cancelar", style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              if (nombreCtrl.text.isEmpty || ciCtrl.text.isEmpty) return;
              Navigator.pop(ctx);
              await provider.registrarExterno(
                qrCode,
                nombreCtrl.text,
                ciCtrl.text,
                telCtrl.text,
              );
              if (mounted)
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Registrado y Acceso Permitido'),
                    backgroundColor: Colors.green,
                  ),
                );
            },
            child: const Text(
              "Registrar y Entrar",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScannerProvider>();
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ), // Botón de volver
      body: Stack(
        children: [
          MobileScanner(
            onDetect: (capture) async {
              if (capture.barcodes.isNotEmpty &&
                  capture.barcodes.first.rawValue != null) {
                String codigoEscaneado = capture.barcodes.first.rawValue!;
                String resultado = await provider.validarQrCode(
                  codigoEscaneado,
                );
                if (resultado == "NUEVO" && mounted) {
                  _mostrarRegistroExpress(context, codigoEscaneado, provider);
                }
              }
            },
          ),
          if (provider.isProcessing)
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 15),
                    Text(
                      "Procesando...",
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
