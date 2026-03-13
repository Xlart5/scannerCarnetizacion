class Environment {
  // Tu URL base de Spring Boot
  static const String apiUrl =
      'http://api.j0o88kckww4cos8cgog80wsw.158.220.117.118.sslip.io';

  // Headers básicos sin seguridad
  static Map<String, String> get defaultHeaders {
    return {'Content-Type': 'application/json', 'Accept': 'application/json'};
  }
}
