import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:scanner_carnetizacion/constans/environment.dart';

enum ScanFeedbackType { none, successEntry, successExit, error, successLiberate }

class ScannerProvider extends ChangeNotifier {
  late DatabaseReference _rtdbRef;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isProcessing = false;
  bool get isProcessing => _isProcessing;

  String _puertaActual = '';

  ScanFeedbackType _feedbackType = ScanFeedbackType.none;
  ScanFeedbackType get feedbackType => _feedbackType;

  List<String> _partidosDisponibles = [];
  List<String> _asociacionesDisponibles = [];

  List<String> get partidosDisponibles => _partidosDisponibles;
  List<String> get asociacionesDisponibles => _asociacionesDisponibles;

  void setPuerta(String tipoPuerta) {
    _puertaActual = tipoPuerta; 

    _rtdbRef = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: 'https://credenciales-f2be2-default-rtdb.firebaseio.com',
    ).ref('monitores/$_puertaActual');

    _cargarListasAutocompletado(); 
  }

  Future<void> _showFeedbackTemporarily(ScanFeedbackType type) async {
    _isProcessing = false; 
    _feedbackType = type;
    notifyListeners();
    
    await Future.delayed(const Duration(seconds: 2));
    
    _feedbackType = ScanFeedbackType.none;
    notifyListeners();
  }

  Future<void> _cargarListasAutocompletado() async {
    try {
      final snapshot = await _firestore.collection('accesos_externos').get();
      Set<String> partidos = {};
      Set<String> asociaciones = {};
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data['partidoPolitico'] != null && data['partidoPolitico'].toString().trim().isNotEmpty) {
          partidos.add(data['partidoPolitico'].toString().trim().toUpperCase());
        }
        if (data['asociacion'] != null && data['asociacion'].toString().trim().isNotEmpty) {
          asociaciones.add(data['asociacion'].toString().trim().toUpperCase());
        }
      }
      _partidosDisponibles = partidos.toList()..sort();
      _asociacionesDisponibles = asociaciones.toList()..sort();
      notifyListeners();
    } catch (e) {
      print("Error al cargar autocompletados: $e");
    }
  }

  Future<Map<String, dynamic>?> buscarExternoPorCI(String ci) async {
    try {
      final query = await _firestore.collection('accesos_externos').where('ci', isEqualTo: ci).get();
      if (query.docs.isNotEmpty) {
        return query.docs.first.data();
      }
    } catch (e) {
      print("Error buscando por CI: $e");
    }
    return null; 
  }

  Future<String> validarQrCode(String rawQrData) async {
    if (_isProcessing || _feedbackType != ScanFeedbackType.none) return "ESPERA";
    _isProcessing = true;
    notifyListeners();

    try {
      final DateTime now = DateTime.now();
      final String fechaHoy = DateFormat('yyyy-MM-dd').format(now);
      final String horaAhora = DateFormat('HH:mm:ss').format(now);

      if (rawQrData.startsWith('EXT-')) {
        DocumentSnapshot doc = await _firestore.collection('accesos_externos').doc(rawQrData).get();
        if (!doc.exists) {
          if (_puertaActual == 'externos_salida') {
            await _enviarAlMonitorWebError("QR inválido. Esta persona no está registrada.");
            await _showFeedbackTemporarily(ScanFeedbackType.error); 
            return "OK";
          }
          _isProcessing = false; notifyListeners();
          return "NUEVO";
        }
        final personaData = doc.data() as Map<String, dynamic>;
        bool estaAdentro = personaData['estaAdentro'] ?? false;
        
        if (_puertaActual == 'externos_entrada' && estaAdentro) {
          await _enviarAlMonitorWebError("ERROR: Esta persona ya registró su INGRESO y está adentro.");
          await _showFeedbackTemporarily(ScanFeedbackType.error); 
          return "OK";
        }
        if (_puertaActual == 'externos_salida' && !estaAdentro) {
          await _enviarAlMonitorWebError("ERROR: Esta persona ya registró su SALIDA y está afuera.");
          await _showFeedbackTemporarily(ScanFeedbackType.error); 
          return "OK";
        }

        String tipo = personaData['tipo'] ?? 'GENERAL';
        String nombre = personaData['nombreCompleto'] ?? '';
        String ci = personaData['ci'] ?? '';
        String tipoRegistro = _puertaActual == 'externos_salida' ? 'salida' : 'entrada';
        bool nuevoEstado = tipoRegistro == 'entrada'; 

        String fechaLogica = fechaHoy;
        if (now.hour < 7) fechaLogica = DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 1)));

        final registroNuevo = {
          'tipo': tipoRegistro, 'fecha': fechaHoy, 'hora': horaAhora, 'timestamp': now.millisecondsSinceEpoch, 'fechaLogica': fechaLogica,
        };

        await _firestore.collection('accesos_externos').doc(rawQrData).update({
          'estaAdentro': nuevoEstado,
          'historialAccesos': FieldValue.arrayUnion([registroNuevo]),
        });
        await _enviarAlMonitorWeb(true, "$tipo EXTERNO", nombre, ci, "", tipoRegistro);
        
        await _showFeedbackTemporarily(nuevoEstado ? ScanFeedbackType.successEntry : ScanFeedbackType.successExit);
        return "OK";
      } 
      else {
        final url = Uri.parse('${Environment.apiUrl}/api/personal/detalles/qrComputo/$rawQrData');
        final response = await http.get(url, headers: Environment.defaultHeaders);

        if (response.statusCode == 200) {
          final data = json.decode(utf8.decode(response.bodyBytes));
          bool tieneAcceso = data['accesoComputo'] ?? false;
          String nombre = data['nombre'] ?? 'Personal';
          String apellido = data['apellidoPaterno'] ?? '';
          String foto = data['imagen'] ?? '';
          String unidad = data['unidad'] ?? 'Sin Unidad';
          String cargo = data['cargo'] ?? 'Sin Cargo';

          if (tieneAcceso) {
            DocumentSnapshot evtDoc = await _firestore.collection('accesos_eventuales').doc(rawQrData).get();
            bool estaAdentroEventual = evtDoc.exists ? ((evtDoc.data() as Map<String, dynamic>)['estaAdentro'] ?? false) : false;
            bool nuevoEstadoEventual = !estaAdentroEventual;
            String tipoRegistroEventual = nuevoEstadoEventual ? 'entrada' : 'salida';

            String fechaLogica = fechaHoy;
            if (now.hour < 7) fechaLogica = DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 1)));

            final registroNuevo = {
              'tipo': tipoRegistroEventual, 'fecha': fechaHoy, 'hora': horaAhora, 'timestamp': now.millisecondsSinceEpoch, 'fechaLogica': fechaLogica,
            };

            await _firestore.collection('accesos_eventuales').doc(rawQrData).set({
              'nombreCompleto': "$nombre $apellido".trim(), 'tipo': 'EVENTUAL', 'unidad': unidad, 'cargo': cargo, 'estaAdentro': nuevoEstadoEventual,
              'historialAccesos': FieldValue.arrayUnion([registroNuevo]),
            }, SetOptions(merge: true));

            await _enviarAlMonitorWeb(true, nombre, apellido, rawQrData, foto, tipoRegistroEventual);
            
            await _showFeedbackTemporarily(nuevoEstadoEventual ? ScanFeedbackType.successEntry : ScanFeedbackType.successExit);
          } else {
            await _enviarAlMonitorWebError("No tiene permisos para el Cómputo.");
            await _showFeedbackTemporarily(ScanFeedbackType.error); 
          }
        } else if (response.statusCode == 404) {
          await _enviarAlMonitorWebError("Persona no encontrada en la Base de Datos.");
          await _showFeedbackTemporarily(ScanFeedbackType.error); 
        } else {
          await _enviarAlMonitorWebError("Error del servidor (Código: ${response.statusCode}).");
          await _showFeedbackTemporarily(ScanFeedbackType.error); 
        }
        return "OK";
      }
    } catch (e) {
      await _enviarAlMonitorWebError("Error de conexión al servidor.");
      await _showFeedbackTemporarily(ScanFeedbackType.error); 
      return "ERROR";
    }
  }

  Future<String> validarQrCodeFirebase(String rawQrData) async {
    if (_isProcessing || _feedbackType != ScanFeedbackType.none) return "ESPERA";
    _isProcessing = true;
    notifyListeners();

    try {
      final DateTime now = DateTime.now();
      final String fechaHoy = DateFormat('yyyy-MM-dd').format(now);
      final String horaAhora = DateFormat('HH:mm:ss').format(now);
      
      String fechaLogica = fechaHoy;
      if (now.hour < 7) fechaLogica = DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 1)));

      if (rawQrData.startsWith('EXT-')) {
        DocumentSnapshot doc = await _firestore.collection('accesos_externos').doc(rawQrData).get();

        if (!doc.exists) {
          if (_puertaActual == 'externos_salida') {
            await _enviarAlMonitorWebError("QR inválido. Esta persona no está registrada.");
            await _showFeedbackTemporarily(ScanFeedbackType.error); 
            return "OK";
          }
          _isProcessing = false; notifyListeners();
          return "NUEVO"; 
        }

        final personaData = doc.data() as Map<String, dynamic>;
        bool estaAdentro = personaData['estaAdentro'] ?? false;
        
        if (_puertaActual == 'externos_entrada' && estaAdentro) {
          await _enviarAlMonitorWebError("ERROR: Esta persona ya registró su INGRESO y está adentro.");
          await _showFeedbackTemporarily(ScanFeedbackType.error); 
          return "OK";
        }

        if (_puertaActual == 'externos_salida' && !estaAdentro) {
          await _enviarAlMonitorWebError("ERROR: Esta persona ya registró su SALIDA y está afuera.");
          await _showFeedbackTemporarily(ScanFeedbackType.error); 
          return "OK";
        }

        String tipo = personaData['tipo'] ?? 'GENERAL';
        String nombre = personaData['nombreCompleto'] ?? '';
        String ci = personaData['ci'] ?? '';

        String tipoRegistro = _puertaActual == 'externos_salida' ? 'salida' : 'entrada';
        bool nuevoEstado = tipoRegistro == 'entrada'; 

        final registroNuevo = {
          'tipo': tipoRegistro, 'fecha': fechaHoy, 'hora': horaAhora, 'timestamp': now.millisecondsSinceEpoch, 'fechaLogica': fechaLogica,
        };

        await _firestore.collection('accesos_externos').doc(rawQrData).update({
          'estaAdentro': nuevoEstado,
          'historialAccesos': FieldValue.arrayUnion([registroNuevo]),
        });

        await _enviarAlMonitorWeb(true, "$tipo EXTERNO", nombre, ci, "", tipoRegistro);
        
        await _showFeedbackTemporarily(nuevoEstado ? ScanFeedbackType.successEntry : ScanFeedbackType.successExit);
        return "OK";
      }

      String ciBusqueda = rawQrData; 
      if (rawQrData.startsWith('QR-')) {
        List<String> partes = rawQrData.split('-');
        if (partes.length >= 2) {
          ciBusqueda = partes[1]; 
        }
      }

      DocumentSnapshot docEventual = await _firestore.collection('usuarios_eventuales').doc(ciBusqueda).get();

      if (docEventual.exists) {
        final data = docEventual.data() as Map<String, dynamic>;

        bool tieneAcceso = data['accesoComputo'] ?? false;
        String nombreCompleto = data['nombreCompleto'] ?? 'Personal';
        String foto = data['imagen'] ?? '';
        
        List<String> partesNombre = nombreCompleto.split(' ');
        String soloNombre = partesNombre.isNotEmpty ? partesNombre[0] : '';
        String soloApellido = partesNombre.length > 1 ? partesNombre.sublist(1).join(' ') : '';
        
        String unidad = data['unidad'] ?? 'Sin Unidad';
        String cargo = data['cargo'] ?? 'Sin Cargo';

        if (tieneAcceso) {
          DocumentReference histRef = _firestore.collection('accesos_eventuales').doc(rawQrData);
          DocumentSnapshot evtDoc = await histRef.get();
          
          bool estaAdentroEventual = evtDoc.exists ? ((evtDoc.data() as Map<String, dynamic>)['estaAdentro'] ?? false) : false;
          bool nuevoEstadoEventual = !estaAdentroEventual;
          String tipoRegistroEventual = nuevoEstadoEventual ? 'entrada' : 'salida';

          final registroNuevo = {
            'tipo': tipoRegistroEventual, 'fecha': fechaHoy, 'hora': horaAhora, 'timestamp': now.millisecondsSinceEpoch, 'fechaLogica': fechaLogica,
          };

          await histRef.set({
            'nombreCompleto': nombreCompleto, 'tipo': 'EVENTUAL', 'unidad': unidad, 'cargo': cargo, 'estaAdentro': nuevoEstadoEventual,
            'historialAccesos': FieldValue.arrayUnion([registroNuevo]),
          }, SetOptions(merge: true));

          await _firestore.collection('usuarios_eventuales').doc(ciBusqueda).update({'estaAdentro': nuevoEstadoEventual});

          await _enviarAlMonitorWeb(true, soloNombre, soloApellido, ciBusqueda, foto, tipoRegistroEventual);
          
          await _showFeedbackTemporarily(nuevoEstadoEventual ? ScanFeedbackType.successEntry : ScanFeedbackType.successExit);
        } else {
          await _enviarAlMonitorWebError("No tiene permisos para el Cómputo.");
          await _showFeedbackTemporarily(ScanFeedbackType.error); 
        }
      } else {
        await _enviarAlMonitorWebError("Carnet no migrado o no existe en Firebase.");
        await _showFeedbackTemporarily(ScanFeedbackType.error); 
      }
      return "OK";
      
    } catch (e) {
      print("Error en validarQrCodeFirebase: $e");
      await _enviarAlMonitorWebError("Error conectando a Firebase.");
      await _showFeedbackTemporarily(ScanFeedbackType.error); 
      return "ERROR";
    }
  }

  Future<String> registrarExterno(String qrId, String nombre, String ci, String celular, String partidoPolitico, String asociacion) async {
    if (_isProcessing) return "ESPERA";
    _isProcessing = true;
    notifyListeners();

    try {
      List<String> partes = qrId.split('-');
      String tipoAsignado = partes.length >= 2 ? partes[1] : "GENERAL";
      final DateTime now = DateTime.now();

      String fechaLogica = DateFormat('yyyy-MM-dd').format(now);
      if (now.hour < 7) fechaLogica = DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 1)));

      final registroNuevo = {
        'tipo': 'entrada', 'fecha': DateFormat('yyyy-MM-dd').format(now), 'hora': DateFormat('HH:mm:ss').format(now), 'timestamp': now.millisecondsSinceEpoch, 'fechaLogica': fechaLogica, 
      };

      String resultadoOperacion = "NUEVO";
      List<dynamic> historialAnterior = [];

      final queryExistente = await _firestore.collection('accesos_externos').where('ci', isEqualTo: ci).get();
      
      if (queryExistente.docs.isNotEmpty) {
        final docAnterior = queryExistente.docs.first;
        final qrAnterior = docAnterior.id;
        
        if (qrAnterior != qrId) {
          historialAnterior = docAnterior.data()['historialAccesos'] ?? [];
          await _firestore.collection('accesos_externos').doc(qrAnterior).delete();
          resultadoOperacion = "TRANSFERIDO";
        }
      }

      historialAnterior.add(registroNuevo);

      final Map<String, dynamic> datosGuardar = {
        'nombreCompleto': nombre.toUpperCase(), 
        'ci': ci, 
        'celular': celular, 
        'tipo': tipoAsignado, 
        'estaAdentro': true, 
        'historialAccesos': historialAnterior,
      };

      if (partidoPolitico.isNotEmpty) datosGuardar['partidoPolitico'] = partidoPolitico.trim().toUpperCase();
      if (asociacion.isNotEmpty) datosGuardar['asociacion'] = asociacion.trim().toUpperCase();

      await _firestore.collection('accesos_externos').doc(qrId).set(datosGuardar);
      await _enviarAlMonitorWeb(true, "$tipoAsignado EXTERNO", nombre.toUpperCase(), ci, "", 'entrada');

      _cargarListasAutocompletado();
      
      await _showFeedbackTemporarily(ScanFeedbackType.successEntry);
      return resultadoOperacion;
    } catch (e) {
      await _showFeedbackTemporarily(ScanFeedbackType.error); 
      return "ERROR";
    }
  }

  // 🔥 NUEVA FUNCIÓN PARA LIBERAR EL QR
  Future<String> liberarCredencial(String qrId) async {
    if (_isProcessing || _feedbackType != ScanFeedbackType.none) return "ESPERA";
    _isProcessing = true;
    notifyListeners();

    try {
      if (!qrId.startsWith('EXT-')) {
        await _showFeedbackTemporarily(ScanFeedbackType.error);
        return "NO_EXTERNO";
      }

      DocumentSnapshot doc = await _firestore.collection('accesos_externos').doc(qrId).get();
      if (!doc.exists) {
        await _showFeedbackTemporarily(ScanFeedbackType.error);
        return "YA_LIBRE";
      }

      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      
      // Si la persona nunca registró su salida, la registramos por seguridad para no dejar su historial "abierto"
      bool estaAdentro = data['estaAdentro'] ?? false;
      if (estaAdentro) {
        final DateTime now = DateTime.now();
        String fechaHoy = DateFormat('yyyy-MM-dd').format(now);
        String horaAhora = DateFormat('HH:mm:ss').format(now);
        String fechaLogica = fechaHoy;
        if (now.hour < 7) fechaLogica = DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 1)));
        
        final registroSalida = {
          'tipo': 'salida', 'fecha': fechaHoy, 'hora': horaAhora, 'timestamp': now.millisecondsSinceEpoch, 'fechaLogica': fechaLogica,
        };
        List<dynamic> historial = data['historialAccesos'] ?? [];
        historial.add(registroSalida);
        data['historialAccesos'] = historial;
        data['estaAdentro'] = false;
      }

      // 🔥 Cambiamos el ID agregando un "-0-" y el timestamp para que sea único en la base de datos
      String nuevoId = "$qrId-0-${DateTime.now().millisecondsSinceEpoch}";
      
      await _firestore.collection('accesos_externos').doc(nuevoId).set(data);
      await _firestore.collection('accesos_externos').doc(qrId).delete();

      await _showFeedbackTemporarily(ScanFeedbackType.successLiberate);
      return "OK";
    } catch (e) {
      print("Error al liberar QR: $e");
      await _showFeedbackTemporarily(ScanFeedbackType.error);
      return "ERROR";
    }
  }

  Future<void> _enviarAlMonitorWeb(bool acceso, String nom, String ape, String ci, String img, String tipoRegistro) async {
    await _rtdbRef.set({"accesoComputo": acceso, "nombre": nom, "apellidoPaterno": ape, "carnetIdentidad": ci, "imagen": img, "tipoRegistro": tipoRegistro, "timestamp": DateTime.now().millisecondsSinceEpoch});
  }

  Future<void> _enviarAlMonitorWebError(String errorMsg) async {
    await _rtdbRef.set({"accesoComputo": false, "error": errorMsg, "timestamp": DateTime.now().millisecondsSinceEpoch});
  }

  void liberarEscaner() {
    _isProcessing = false; 
    _feedbackType = ScanFeedbackType.none; 
    notifyListeners();
  }
}