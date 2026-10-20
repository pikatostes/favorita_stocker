import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'auth_controller.dart';
import 'db.dart';
import 'seed_runner.dart';
import 'screens/auth.dart';
import 'screens/home.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Localización y catálogo inicial son independientes: se cargan a la vez.
  await Future.wait([
    initializeDateFormatting('es'),
    initializeSeedData(),
  ]);
  await AuthController.i.restore();
  runApp(const StockBarApp());
  // Limpieza del histórico de 2 años: es mantenimiento, no debe retrasar el
  // primer frame ni bloquear la UI.
  unawaited(Db.i.purgeOld().catchError((Object error, StackTrace stack) {
    debugPrint('No se pudo purgar el histórico antiguo: $error');
  }));
}

class StockBarApp extends StatelessWidget {
  const StockBarApp({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<AppPalette>(
        valueListenable: selectedPalette,
        builder: (_, palette, __) => AnimatedBuilder(
          animation: AuthController.i,
          builder: (_, __) => MaterialApp(
            title: 'Stock Bar',
            locale: const Locale('es'),
            supportedLocales: const [Locale('es')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            theme: palette.light,
            darkTheme: palette.dark,
            home: AuthController.i.isSignedIn
                ? const HomeScreen()
                : const AuthScreen(),
          ),
        ),
      );
}
