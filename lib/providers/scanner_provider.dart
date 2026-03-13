import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:scanner_carnetizacion/constans/environment.dart';

// 🔥 Importa tu Environment para usar el Token y la URL Base
// (Ajusta la ruta si es necesario según tu proyecto del escáner)

class ScannerProvider extends ChangeNotifier {
  late DatabaseReference _rtdbRef;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isProcessing = false;
  bool get isProcessing => _isProcessing;

  String _puertaActual = '';

  // ==========================================
  // FUNCIÓN PARA CONFIGURAR LA PUERTA AL INICIAR
  // ==========================================
  void setPuerta(String tipoPuerta) {
    _puertaActual =
        tipoPuerta; // Ej: 'externos_entrada', 'externos_salida', 'eventuales'

    // Conectamos el celular al canal específico de esta puerta
    _rtdbRef = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: 'https://credenciales-f2be2-default-rtdb.firebaseio.com',
    ).ref('monitores/$_puertaActual');
  }

  // ==========================================
  // FUNCIÓN PRINCIPAL DE LECTURA DEL QR
  // ==========================================
  Future<String> validarQrCode(String rawQrData) async {
    if (_isProcessing) return "ESPERA";

    _isProcessing = true;
    notifyListeners();

    try {
      final DateTime now = DateTime.now();
      final String fechaHoy = DateFormat('yyyy-MM-dd').format(now);
      final String horaAhora = DateFormat('HH:mm:ss').format(now);

      // ==========================================
      // CASO A: ES UN EXTERNO (Firebase Firestore)
      // ==========================================
      if (rawQrData.startsWith('EXT-')) {
        DocumentSnapshot doc = await _firestore
            .collection('accesos_externos')
            .doc(rawQrData)
            .get();

        if (!doc.exists) {
          // 🔥 Si un guardia de SALIDA escanea un QR vacío, ¡Tira error!
          if (_puertaActual == 'externos_salida') {
            await _enviarAlMonitorWebError(
              "QR inválido. Esta persona no está registrada.",
            );
            await Future.delayed(const Duration(seconds: 3));
            _isProcessing = false;
            notifyListeners();
            return "OK";
          }
          // Si es el guardia de INGRESO, devolvemos "NUEVO" para abrir el formulario
          return "NUEVO";
        }

        // EL QR YA ESTÁ REGISTRADO
        final personaData = doc.data() as Map<String, dynamic>;
        String tipo = personaData['tipo'] ?? 'GENERAL';
        String nombre = personaData['nombreCompleto'] ?? '';
        String ci = personaData['ci'] ?? '';

        // 🔥 OBLIGAMOS EL TIPO DE REGISTRO SEGÚN EL ROL DEL GUARDIA
        String tipoRegistro = _puertaActual == 'externos_salida'
            ? 'salida'
            : 'entrada';
        bool nuevoEstado =
            tipoRegistro == 'entrada'; // True si entra, False si sale

        final registroNuevo = {
          'tipo': tipoRegistro,
          'fecha': fechaHoy,
          'hora': horaAhora,
          'timestamp': now.millisecondsSinceEpoch,
        };

        // Guardamos en Firestore
        await _firestore.collection('accesos_externos').doc(rawQrData).update({
          'estaAdentro': nuevoEstado,
          'historialAccesos': FieldValue.arrayUnion([registroNuevo]),
        });

        // Enviamos la señal a la PC Monitor de este canal
        await _enviarAlMonitorWeb(
          true,
          "$tipo EXTERNO",
          nombre,
          ci,
          "",
          tipoRegistro,
        );

        await Future.delayed(const Duration(seconds: 2));
        _isProcessing = false;
        notifyListeners();
        return "OK";
      }
      // ==========================================
      // CASO B: ES PERSONAL EVENTUAL (Spring Boot)
      // ==========================================
      // ==========================================
      // CASO B: ES PERSONAL EVENTUAL (Spring Boot)
      // ==========================================
      // ==========================================
      // CASO B: ES PERSONAL EVENTUAL (Spring Boot)
      // ==========================================
      else {
        final url = Uri.parse(
          '${Environment.apiUrl}/api/personal/detalles/qrComputo/$rawQrData',
        );

        // 🔥 AHORA HACE LA PETICIÓN SIN TOKEN
        final response = await http.get(
          url,
          headers: Environment.defaultHeaders,
        );

        if (response.statusCode == 200) {
          final data = json.decode(utf8.decode(response.bodyBytes));

          bool tieneAcceso = data['accesoComputo'] ?? false;
          String nombre = data['nombre'] ?? 'Personal';
          String apellido = data['apellidoPaterno'] ?? '';
          String foto = data['imagen'] ?? '';
          String tipoRegistro = 'entrada';

          if (tieneAcceso) {
            await _enviarAlMonitorWeb(
              true,
              nombre,
              apellido,
              rawQrData,
              foto,
              tipoRegistro,
            );
          } else {
            await _enviarAlMonitorWebError(
              "No tiene permisos para el Cómputo.",
            );
          }
        } else if (response.statusCode == 404) {
          await _enviarAlMonitorWebError(
            "Persona no encontrada en la Base de Datos.",
          );
        } else {
          await _enviarAlMonitorWebError(
            "Error del servidor (Código: ${response.statusCode}).",
          );
        }

        await Future.delayed(const Duration(seconds: 2));
        _isProcessing = false;
        notifyListeners();
        return "OK";
      }
    } catch (e) {
      print("Error en validarQrCode: $e");
      await _enviarAlMonitorWebError("Error de conexión al servidor.");
      _isProcessing = false;
      notifyListeners();
      return "ERROR";
    }
  }

  // ==========================================
  // FUNCIÓN PARA REGISTRAR NUEVO EXTERNO DESDE EL CELULAR
  // ==========================================
  Future<bool> registrarExterno(
    String qrId,
    String nombre,
    String ci,
    String celular,
  ) async {
    try {
      List<String> partes = qrId.split('-');
      String tipoAsignado = partes.length >= 2 ? partes[1] : "GENERAL";
      final DateTime now = DateTime.now();

      // Si lo estamos registrando en la puerta, obligatoriamente está entrando
      final registroNuevo = {
        'tipo': 'entrada',
        'fecha': DateFormat('yyyy-MM-dd').format(now),
        'hora': DateFormat('HH:mm:ss').format(now),
        'timestamp': now.millisecondsSinceEpoch,
      };

      await _firestore.collection('accesos_externos').doc(qrId).set({
        'nombreCompleto': nombre.toUpperCase(),
        'ci': ci,
        'celular': celular,
        'tipo': tipoAsignado,
        'estaAdentro': true,
        'historialAccesos': [registroNuevo],
      });

      // Le avisamos a la PC que le dé la bienvenida
      await _enviarAlMonitorWeb(
        true,
        "$tipoAsignado EXTERNO",
        nombre.toUpperCase(),
        ci,
        "",
        'entrada',
      );

      await Future.delayed(const Duration(seconds: 2));
      _isProcessing = false;
      notifyListeners();
      return true;
    } catch (e) {
      print("Error registrando externo: $e");
      _isProcessing = false;
      notifyListeners();
      return false;
    }
  }

  // ==========================================
  // HELPERS PARA MANDAR LA SEÑAL A LA PC (Firebase RTDB)
  // ==========================================
  Future<void> _enviarAlMonitorWeb(
    bool acceso,
    String nom,
    String ape,
    String ci,
    String img,
    String tipoRegistro,
  ) async {
    await _rtdbRef.set({
      "accesoComputo": acceso,
      "nombre": nom,
      "apellidoPaterno": ape,
      "carnetIdentidad": ci,
      "imagen": img,
      "tipoRegistro": tipoRegistro,
      "timestamp": DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> _enviarAlMonitorWebError(String errorMsg) async {
    await _rtdbRef.set({
      "accesoComputo": false,
      "error": errorMsg,
      "timestamp": DateTime.now().millisecondsSinceEpoch,
    });
  }

  // Desbloquea la cámara si el guardia cancela el formulario
  void liberarEscaner() {
    _isProcessing = false;
    notifyListeners();
  }
}
