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

  // LA FUNCIÓN PRINCIPAL: Procesa el QR
  Future<void> validarQrCode(String rawQrData) async {
    _state = ScannerState.loading;
    notifyListeners();

    try {
      // 1. Parsear el String del QR
      // Ejemplo: "QR-8855837-20260218-493E6D02"
      final parts = rawQrData.split('-');
      if (parts.length < 2) {
        _setError("Formato de QR no válido");
        return;
      }
      final ciBuscado = parts[1]; // Obtenemos "8855837"

      print("Buscando C.I.: $ciBuscado...");

      // 2. Llamar a la API (Usamos el endpoint de detalles que devuelve toda la lista)
      // ⚠️ NOTA: Lo ideal sería tener un endpoint en el backend tipo: /api/personal/buscar/{ci}
      // Pero usaremos el que tenemos disponible ahora.
      final url = Uri.parse('$_baseUrl/api/personal/detalles');
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          // Por si acaso con ngrok
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> todaLaLista = json.decode(
          utf8.decode(response.bodyBytes),
        );

        // 3. Buscar a la persona específica en la lista por su C.I.
        try {
          final persona = todaLaLista.firstWhere(
            (p) => p['carnetIdentidad'].toString() == ciBuscado,
          );

          _personaEncontrada = persona;

          // 4. Verificar el acceso a cómputo
          final bool tieneAcceso = persona['accesoComputo'] == true;

          if (tieneAcceso) {
            _state = ScannerState.success; // ¡Acceso Permitido!
          } else {
            _state = ScannerState.denied; // Acceso Denegado
          }
        } catch (e) {
          // Si no encuentra el C.I. en la lista
          _state = ScannerState.notFound;
        }
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
