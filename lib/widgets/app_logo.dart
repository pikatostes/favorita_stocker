import 'package:flutter/material.dart';

/// Logotipo de La Favorita. Se usa como título en la barra superior de cada
/// pestaña (Lista, Previsión, Turnos, Calendario y Productos).
class AppLogo extends StatelessWidget {
  /// Alto del logotipo dentro de la barra superior.
  final double height;

  const AppLogo({super.key, this.height = 36});

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Image.asset(
          'lib/img/la-favorita-logo.png',
          height: height,
          fit: BoxFit.contain,
          semanticLabel: 'La Favorita',
        ),
      );
}
