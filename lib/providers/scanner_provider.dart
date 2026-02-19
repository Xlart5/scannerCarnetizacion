import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart'; // <-- IMPORTAMOS LA VOZ

enum ScannerState { idle, loading, success, denied, notFound, error }

class ScannerProvider extends ChangeNotifier {
  final String _baseUrl = 'https://c5dc-192-223-121-131.ngrok-free.app';
  final FlutterTts _flutterTts = FlutterTts(); // Instancia de la voz

  ScannerState _state = ScannerState.idle;
  Map<String, dynamic>? _personaEncontrada;
  String _errorMessage = '';

  ScannerState get state => _state;
  Map<String, dynamic>? get personaEncontrada => _personaEncontrada;
  String get errorMessage => _errorMessage;

  ScannerProvider() {
    _configurarVoz();
  }

  // 1. Configuramos la voz para que hable español y ESPERE a terminar
  Future<void> _configurarVoz() async {
    await _flutterTts.setLanguage("es-US");
    await _flutterTts.setSpeechRate(1); // Velocidad normal
    await _flutterTts.awaitSpeakCompletion(
      true,
    ); // ¡Vital para que espere antes de cerrar!
  }

  // 2. Función para que el celular hable según el resultado
  Future<void> reproducirVoz() async {
    if (_state == ScannerState.success) {
      String nombre = _personaEncontrada?['nombre'] ?? '';
      String paterno = _personaEncontrada?['apellidoPaterno'] ?? '';
      await _flutterTts.speak("Acceso permitido. Bienvenido, $nombre $paterno");
    } else if (_state == ScannerState.denied) {
      await _flutterTts.speak("Acceso denegado. $_errorMessage");
    } else {
      await _flutterTts.speak("Error al leer el código.");
    }
  }

  // --- TRUCO PARA DESBLOQUEAR AUDIO EN NAVEGADORES MÓVILES ---
  Future<void> desbloquearAudioWeb() async {
    await _flutterTts.setVolume(0.0); // Le bajamos el volumen a cero
    await _flutterTts.speak(" "); // Hablamos un espacio en blanco
    await _flutterTts.setVolume(
      1.0,
    ); // Volvemos a subir el volumen para después
  }

  void resetScanner() {
    _state = ScannerState.idle;
    _personaEncontrada = null;
    notifyListeners();
  }

  // 3. Validación de QR y manejo del Error 403
  Future<void> validarQrCode(String rawQrData) async {
    _state = ScannerState.loading;
    notifyListeners();

    try {
      final url = Uri.parse(
        '$_baseUrl/api/personal/detalles/qrComputo/$rawQrData',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final persona = json.decode(utf8.decode(response.bodyBytes));
        _personaEncontrada = persona;

        if (persona['accesoComputo'] == true) {
          _state = ScannerState.success;
        } else {
          _state = ScannerState.denied;
          _errorMessage = "No tiene permisos de acceso.";
        }
      }
      // ¡AQUÍ ATRAPAMOS EL ERROR 403 y 404!
      else if (response.statusCode == 403 || response.statusCode == 404) {
        _state = ScannerState.denied; // Forzamos la pantalla Roja
        _errorMessage =
            "La persona no está registrada."; // Tu mensaje personalizado
      } else {
        _setError("Error del servidor: ${response.statusCode}");
      }
    } catch (e) {
      _setError("Error de conexión al servidor.");
    } finally {
      notifyListeners();
    }
  }

  void _setError(String msg) {
    _state = ScannerState.error;
    _errorMessage = msg;
    print(msg);
  }
}
