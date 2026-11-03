/// Validación sencilla: texto@dominio.tld, sin espacios.
///
/// El hash de contraseñas y la sesión los gestiona Supabase Auth, así que aquí
/// solo queda la validación de email que usa el formulario.
bool isValidEmail(String value) =>
    RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim());
