import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Contraseña temporal de las cuentas creadas por la semilla o por la
/// migración de los antiguos empleados.
const String kSeedPassword = 'favorita';

/// Validación sencilla: texto@dominio.tld, sin espacios.
bool isValidEmail(String value) =>
    RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim());

/// Hash de contraseñas con sal aleatoria y varias iteraciones de SHA-256.
///
/// No es un KDF de memoria dura (tipo Argon2), pero evita guardar la
/// contraseña en claro y encarece bastante un ataque por diccionario local.
class PasswordHasher {
  static const int _iterations = 20000;
  static const int _saltBytes = 16;

  /// Sal nueva codificada en base64url.
  static String newSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(_saltBytes, (_) => random.nextInt(256));
    return base64Url.encode(bytes);
  }

  /// Hash de [password] con [salt], codificado en base64url.
  static String hash(String password, String salt) {
    var digest = sha256.convert(utf8.encode('$salt:$password'));
    final saltBytes = utf8.encode(salt);
    for (var i = 0; i < _iterations; i++) {
      digest = sha256.convert([...digest.bytes, ...saltBytes]);
    }
    return base64Url.encode(digest.bytes);
  }

  /// Comprueba [password] contra [expectedHash] sin cortocircuitar la
  /// comparación por el primer byte distinto.
  static bool verify(String password, String salt, String expectedHash) {
    final actual = hash(password, salt);
    if (actual.length != expectedHash.length) return false;
    var diff = 0;
    for (var i = 0; i < actual.length; i++) {
      diff |= actual.codeUnitAt(i) ^ expectedHash.codeUnitAt(i);
    }
    return diff == 0;
  }
}
