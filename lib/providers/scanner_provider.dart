import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// Estados posibles del proceso de escaneo
enum ScannerState { idle, loading, success, denied, notFound, error }

class ScannerProvider extends ChangeNotifier {
  // ⚠️ IMPORTANTE: Usa la URL de Ngrok que tengas activa hoy en tu environment.dart
  // Como es una app móvil, NO puedes usar "localhost".
  final String _baseUrl = 'https://c5dc-192-223-121-131.ngrok-free.app';

  ScannerState _state = ScannerState.idle;
  Map<String, dynamic>? _personaEncontrada;
  String _errorMessage = '';

  ScannerState get state => _state;
  Map<String, dynamic>? get personaEncontrada => _personaEncontrada;
  String get errorMessage => _errorMessage;

  // Función para resetear y volver a escanear
  void resetScanner() {
    _state = ScannerState.idle;
    _personaEncontrada = null;
    notifyListeners();
  }

  // LA FUNCIÓN PRINCIPAL: Procesa el QR directo con tu nuevo endpoint
  Future<void> validarQrCode(String rawQrData) async {
    _state = ScannerState.loading;
    notifyListeners();

    try {
      print("Consultando acceso para el QR: $rawQrData");

      // Llamamos directo a tu nuevo endpoint
      final url = Uri.parse(
        '$_baseUrl/api/personal/detalles/qrComputo/$rawQrData',
      );

      final response = await http.get(
        url,
        headers: {
          // Vital para Ngrok
        },
      );

      if (response.statusCode == 200) {
        // Obtenemos los datos de la persona escaneada
        final persona = json.decode(utf8.decode(response.bodyBytes));
        _personaEncontrada = persona;

        // Leemos el booleano que manda el backend
        final bool tieneAcceso = persona['accesoComputo'] == true;

        if (tieneAcceso) {
          _state = ScannerState.success; // Pantalla Verde/Amarilla (Éxito)
        } else {
          _state = ScannerState.denied; // Pantalla Roja (Denegado)
        }
      } else if (response.statusCode == 404 || response.statusCode == 204) {
        // Si el backend responde que no existe ese QR
        _state = ScannerState.notFound;
      } else {
        _setError("Error del servidor: ${response.statusCode}");
      }
    } catch (e) {
      _setError("Error de conexión: $e");
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
