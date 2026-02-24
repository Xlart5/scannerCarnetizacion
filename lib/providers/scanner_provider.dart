import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_database/firebase_database.dart';

class ScannerProvider extends ChangeNotifier {
  final String _baseUrl = 'https://c5dc-192-223-121-131.ngrok-free.app';

  // Referencia directa a la "carpeta" donde guardaremos el escaneo en Firebase
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref(
    'ultimo_escaneo',
  );

  bool _isProcessing = false;
  bool get isProcessing => _isProcessing;

  Future<void> validarQrCode(String rawQrData) async {
    if (_isProcessing) return;

    _isProcessing = true;
    notifyListeners();

    try {
      final url = Uri.parse(
        '$_baseUrl/api/personal/detalles/qrComputo/$rawQrData',
      );
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode == 200) {
        // ¡Éxito! Decodificamos el JSON y lo ESCRIBIMOS en Firebase
        final persona = json.decode(utf8.decode(response.bodyBytes));

        // Le agregamos la hora exacta para que Firebase sepa que es un dato nuevo
        persona['timestamp'] = DateTime.now().millisecondsSinceEpoch;

        await _dbRef.set(persona);
      } else if (response.statusCode == 403 || response.statusCode == 404) {
        // Denegado
        await _dbRef.set({
          "accesoComputo": false,
          "error": "La persona no está registrada.",
          "timestamp": DateTime.now().millisecondsSinceEpoch,
        });
      }
    } catch (e) {
      await _dbRef.set({
        "accesoComputo": false,
        "error": "Error de conexión.",
        "timestamp": DateTime.now().millisecondsSinceEpoch,
      });
    }

    await Future.delayed(const Duration(seconds: 2));
    _isProcessing = false;
    notifyListeners();
  }
}
