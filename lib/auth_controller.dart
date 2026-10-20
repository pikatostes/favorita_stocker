import 'package:flutter/foundation.dart';

import 'db.dart';
import 'shifts.dart';

/// Estado global de la sesión. La pantalla raíz escucha este controlador para
/// mostrar el login o la aplicación.
class AuthController extends ChangeNotifier {
  AuthController._();
  static final AuthController i = AuthController._();

  AppUser? _user;
  AppUser? get user => _user;
  bool get isSignedIn => _user != null;

  /// Recupera la sesión guardada en `app_metadata` al arrancar.
  Future<void> restore() async {
    _user = await Db.i.currentUser();
    notifyListeners();
  }

  /// Inicia sesión. Devuelve `null` si fue bien o el mensaje de error.
  Future<String?> login(String email, String password) async {
    try {
      final user = await Db.i.authenticate(email, password);
      if (user == null) return 'Email o contraseña incorrectos.';
      _user = user;
      notifyListeners();
      return null;
    } on StateError catch (e) {
      return e.message;
    } catch (e) {
      return 'No se pudo iniciar sesión: $e';
    }
  }

  /// Crea una cuenta y deja la sesión iniciada.
  Future<String?> register({
    required String name,
    required String surname,
    required String email,
    required String password,
  }) async {
    try {
      _user = await Db.i.registerUser(
        name: name,
        surname: surname,
        email: email,
        password: password,
      );
      notifyListeners();
      return null;
    } on StateError catch (e) {
      return e.message;
    } on ArgumentError catch (e) {
      return e.message?.toString() ?? 'Datos de registro no válidos.';
    } catch (e) {
      return 'No se pudo crear la cuenta: $e';
    }
  }

  /// Vuelve a leer el usuario de la base de datos (tras editar el perfil).
  Future<void> refresh() async {
    final id = _user?.id;
    if (id == null) return;
    final updated = await Db.i.userById(id);
    if (updated == null || !updated.active) {
      await logout();
      return;
    }
    _user = updated;
    notifyListeners();
  }

  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final id = _user?.id;
    if (id == null) return 'No hay una sesión iniciada.';
    try {
      await Db.i.changePassword(id, currentPassword, newPassword);
      return null;
    } on StateError catch (e) {
      return e.message;
    } on ArgumentError catch (e) {
      return e.message?.toString() ?? 'La contraseña no es válida.';
    } catch (e) {
      return 'No se pudo cambiar la contraseña: $e';
    }
  }

  Future<void> logout() async {
    await Db.i.logout();
    _user = null;
    notifyListeners();
  }
}
