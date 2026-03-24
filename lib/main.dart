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
        home: SeleccionPuertaScreen(), 
        debugShowCheckedModeBanner: false,
      ),
    ),
  );
}

class SeleccionPuertaScreen extends StatelessWidget {
  const SeleccionPuertaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E293B),
      drawer: Drawer(
        backgroundColor: const Color(0xFF1E293B),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.black),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.admin_panel_settings, color: Colors.orange, size: 40),
                  SizedBox(height: 10),
                  Text("Opciones Avanzadas", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.flash_on, color: Colors.yellow),
              title: const Text("Modo Rápido (Firebase)", style: TextStyle(color: Colors.white)),
              subtitle: const Text("Escáner ultra rápido sin API", style: TextStyle(color: Colors.white54, fontSize: 12)),
              onTap: () {
                Navigator.pop(context); 
                context.read<ScannerProvider>().setPuerta('eventuales'); 
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ScannerFirebaseScreen())); 
              },
            ),
            // 🔥 AQUÍ MOVIMOS LA FUNCIÓN DE LIBERAR QR
            ListTile(
              leading: const Icon(Icons.autorenew, color: Colors.purpleAccent),
              title: const Text("Liberar Credencial", style: TextStyle(color: Colors.white)),
              subtitle: const Text("Reciclar código QR para nuevo uso", style: TextStyle(color: Colors.white54, fontSize: 12)),
              onTap: () {
                Navigator.pop(context); // Cierra el Drawer
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ScannerLiberarScreen())); 
              },
            ),
          ],
        ),
      ),
      appBar: AppBar(
        title: const Text("SISTEMA TED"),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white), 
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Seleccione su Rol", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 40),

              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15)),
                icon: const Icon(Icons.login, size: 30, color: Colors.white),
                label: const Text("Externos - INGRESO", style: TextStyle(fontSize: 18, color: Colors.white)),
                onPressed: () {
                  context.read<ScannerProvider>().setPuerta('externos_entrada');
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ScannerScreen()));
                },
              ),
              const SizedBox(height: 20),

              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, padding: const EdgeInsets.symmetric(horizontal: 45, vertical: 15)),
                icon: const Icon(Icons.logout, size: 30, color: Colors.white),
                label: const Text("Externos - SALIDA", style: TextStyle(fontSize: 18, color: Colors.white)),
                onPressed: () {
                  context.read<ScannerProvider>().setPuerta('externos_salida');
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ScannerScreen()));
                },
              ),
              const SizedBox(height: 40),
              const Divider(color: Colors.white24, indent: 50, endIndent: 50),
              const SizedBox(height: 40),

              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, padding: const EdgeInsets.symmetric(horizontal: 55, vertical: 15)),
                icon: const Icon(Icons.badge, size: 30, color: Colors.white),
                label: const Text("Personal EVENTUAL", style: TextStyle(fontSize: 18, color: Colors.white)),
                onPressed: () {
                  context.read<ScannerProvider>().setPuerta('eventuales');
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ScannerScreen()));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> mostrarRegistroExpressUniversal(BuildContext context, String qrCode, ScannerProvider provider) async {
  final nombreCtrl = TextEditingController();
  final ciCtrl = TextEditingController();
  final telCtrl = TextEditingController();
  
  final partidoCtrl = TextEditingController(); 
  final asociacionCtrl = TextEditingController(); 

  List<String> partes = qrCode.split('-');
  String tipoAsignado = partes.length >= 2 ? partes[1].toUpperCase() : "GENERAL";
  
  bool pidePartido = tipoAsignado == 'CANDIDATO' || tipoAsignado == 'DELEGADO';
  bool pideAsociacion = tipoAsignado == 'OBSERVADOR';

  void buscarYAutocompletarPorCI(String ciIngresado) async {
    if (ciIngresado.trim().isEmpty) return;
    var datos = await provider.buscarExternoPorCI(ciIngresado.trim());
    if (datos != null) {
      nombreCtrl.text = datos['nombreCompleto'] ?? '';
      telCtrl.text = datos['celular'] ?? '';
      if (pidePartido) partidoCtrl.text = datos['partidoPolitico'] ?? '';
      if (pideAsociacion) asociacionCtrl.text = datos['asociacion'] ?? '';
    }
  }

  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const Text("Registrar Externo", style: TextStyle(fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("QR: $qrCode", style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 15),

            TextField(
              controller: ciCtrl,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.search, 
              onSubmitted: (value) => buscarYAutocompletarPorCI(value), 
              decoration: InputDecoration(
                labelText: "Carnet de Identidad *", 
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search, color: Colors.blueAccent),
                  onPressed: () => buscarYAutocompletarPorCI(ciCtrl.text), 
                  tooltip: "Buscar datos previos",
                ),
              ),
            ),
            const SizedBox(height: 10),

            TextField(
              controller: nombreCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: "Nombre Completo *", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            
            TextField(
              controller: telCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: "Teléfono Celular", border: OutlineInputBorder()),
            ),
            
            if (pidePartido) ...[
              const SizedBox(height: 10),
              Autocomplete<String>(
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text.isEmpty) return provider.partidosDisponibles;
                  return provider.partidosDisponibles.where((String option) {
                    return option.toUpperCase().contains(textEditingValue.text.toUpperCase());
                  });
                },
                onSelected: (String selection) => partidoCtrl.text = selection,
                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                  if (partidoCtrl.text.isNotEmpty && controller.text.isEmpty) {
                    controller.text = partidoCtrl.text;
                  }
                  controller.addListener(() => partidoCtrl.text = controller.text);
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: "Partido Político *", 
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.arrow_drop_down, color: Colors.blueAccent),
                    ),
                  );
                },
              ),
            ],

            if (pideAsociacion) ...[
              const SizedBox(height: 10),
              Autocomplete<String>(
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text.isEmpty) return provider.asociacionesDisponibles;
                  return provider.asociacionesDisponibles.where((String option) {
                    return option.toUpperCase().contains(textEditingValue.text.toUpperCase());
                  });
                },
                onSelected: (String selection) => asociacionCtrl.text = selection,
                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                  if (asociacionCtrl.text.isNotEmpty && controller.text.isEmpty) {
                    controller.text = asociacionCtrl.text;
                  }
                  controller.addListener(() => asociacionCtrl.text = controller.text);
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: "Asociación u Organización *", 
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.arrow_drop_down, color: Colors.deepPurpleAccent),
                    ),
                  );
                },
              ),
            ],
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
            if (pidePartido && partidoCtrl.text.isEmpty) return; 
            if (pideAsociacion && asociacionCtrl.text.isEmpty) return; 

            Navigator.pop(ctx);
            
            String resultado = await provider.registrarExterno(
              qrCode, nombreCtrl.text, ciCtrl.text, telCtrl.text, pidePartido ? partidoCtrl.text : "", pideAsociacion ? asociacionCtrl.text : "",
            );

            if (resultado == "TRANSFERIDO" && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✅ Historial Transferido. El QR anterior quedó libre.'), 
                  backgroundColor: Colors.orange, 
                  duration: Duration(seconds: 4),
                ),
              );
            }
          },
          child: const Text("Registrar y Entrar", style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
}

Widget _buildFeedbackOverlay(ScanFeedbackType type) {
  if (type == ScanFeedbackType.none) return const SizedBox.shrink();

  IconData iconData;
  Color iconColor;
  String text;

  switch (type) {
    case ScanFeedbackType.successEntry:
      iconData = Icons.check_circle; 
      iconColor = Colors.greenAccent;
      text = "INGRESO";
      break;
    case ScanFeedbackType.successExit:
      iconData = Icons.door_sliding_outlined; 
      iconColor = Colors.blueAccent;
      text = "SALIDA";
      break;
    case ScanFeedbackType.successLiberate:
      iconData = Icons.autorenew; 
      iconColor = Colors.purpleAccent;
      text = "LIBERADO";
      break;
    case ScanFeedbackType.error:
      iconData = Icons.cancel; 
      iconColor = Colors.redAccent;
      text = "ERROR";
      break;
    default:
      return const SizedBox.shrink();
  }

  return Center(
    child: Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: iconColor, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconData, color: iconColor, size: 100), 
          const SizedBox(height: 15),
          Text(
            text, 
            style: TextStyle(color: iconColor, fontSize: 24, fontWeight: FontWeight.bold)
          ),
        ],
      ),
    ),
  );
}

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});
  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  bool _isScannerLocked = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScannerProvider>();
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.transparent, iconTheme: const IconThemeData(color: Colors.white)),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: (capture) async {
              if (_isScannerLocked || provider.isProcessing || provider.feedbackType != ScanFeedbackType.none) return;

              if (capture.barcodes.isNotEmpty && capture.barcodes.first.rawValue != null) {
                setState(() => _isScannerLocked = true);
                
                String codigoEscaneado = capture.barcodes.first.rawValue!;
                String resultado = await provider.validarQrCode(codigoEscaneado);
                
                if (resultado == "NUEVO" && mounted) {
                  await mostrarRegistroExpressUniversal(context, codigoEscaneado, provider);
                }
                
                if (mounted) {
                  setState(() => _isScannerLocked = false);
                }
              }
            },
          ),
          
          if (provider.isProcessing)
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(20)),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 15),
                    Text("Procesando...", style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
            
          _buildFeedbackOverlay(provider.feedbackType),
        ],
      ),
    );
  }
}

class ScannerFirebaseScreen extends StatefulWidget {
  const ScannerFirebaseScreen({super.key});
  @override
  State<ScannerFirebaseScreen> createState() => _ScannerFirebaseScreenState();
}

class _ScannerFirebaseScreenState extends State<ScannerFirebaseScreen> {
  bool _isScannerLocked = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScannerProvider>();
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent, 
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text("Modo Firebase ⚡", style: TextStyle(color: Colors.yellow, fontSize: 16)),
      ),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: (capture) async {
              if (_isScannerLocked || provider.isProcessing || provider.feedbackType != ScanFeedbackType.none) return;

              if (capture.barcodes.isNotEmpty && capture.barcodes.first.rawValue != null) {
                setState(() => _isScannerLocked = true);

                String codigoEscaneado = capture.barcodes.first.rawValue!;
                String resultado = await provider.validarQrCodeFirebase(codigoEscaneado);
                
                if (resultado == "NUEVO" && mounted) {
                  await mostrarRegistroExpressUniversal(context, codigoEscaneado, provider);
                }
                
                if (mounted) {
                  setState(() => _isScannerLocked = false);
                }
              }
            },
          ),
          
          if (provider.isProcessing)
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(20)),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.yellow),
                    SizedBox(height: 15),
                    Text("Validando Rápido...", style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
            
          _buildFeedbackOverlay(provider.feedbackType),
        ],
      ),
    );
  }
}

// =======================================================================
// 🔥 PANTALLA EXCLUSIVA PARA LIBERAR CREDENCIALES
// =======================================================================
class ScannerLiberarScreen extends StatefulWidget {
  const ScannerLiberarScreen({super.key});
  @override
  State<ScannerLiberarScreen> createState() => _ScannerLiberarScreenState();
}

class _ScannerLiberarScreenState extends State<ScannerLiberarScreen> {
  bool _isScannerLocked = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScannerProvider>();
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent, 
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text("Liberar Credencial ♻️", style: TextStyle(color: Colors.purpleAccent, fontSize: 18)),
      ),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: (capture) async {
              if (_isScannerLocked || provider.isProcessing || provider.feedbackType != ScanFeedbackType.none) return;

              if (capture.barcodes.isNotEmpty && capture.barcodes.first.rawValue != null) {
                setState(() => _isScannerLocked = true);

                String codigoEscaneado = capture.barcodes.first.rawValue!;
                String resultado = await provider.liberarCredencial(codigoEscaneado);
                
                if (mounted) {
                  if (resultado == "YA_LIBRE") {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Este QR ya está libre o no existe'), backgroundColor: Colors.orange));
                  } else if (resultado == "NO_EXTERNO") {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Solo puedes liberar credenciales externas (EXT-)'), backgroundColor: Colors.red));
                  }
                  
                  setState(() => _isScannerLocked = false);
                }
              }
            },
          ),
          
          if (provider.isProcessing)
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(20)),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.purpleAccent),
                    SizedBox(height: 15),
                    Text("Liberando QR...", style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
            
          _buildFeedbackOverlay(provider.feedbackType),
        ],
      ),
    );
  }
} 