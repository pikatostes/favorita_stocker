import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_controller.dart';
import 'screens/auth.dart';
import 'screens/forced_password.dart';
import 'screens/home.dart';
import 'theme.dart';

/// URL y clave pública del proyecto Supabase.
///
/// Se pasan en tiempo de compilación para no guardarlas en el código:
///
///     flutter run --dart-define-from-file=env.json
///
/// La clave es la publicable (`sb_publishable_…`): la seguridad real la
/// imponen las políticas RLS del servidor.
const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (_supabaseUrl.isEmpty || _supabaseKey.isEmpty) {
    throw StateError(
      'Faltan SUPABASE_URL y SUPABASE_PUBLISHABLE_KEY.\n'
      'Arranca con: flutter run --dart-define-from-file=env.json',
    );
  }

  await Supabase.initialize(
    url: _supabaseUrl,
    publishableKey: _supabaseKey,
  );
  await initializeDateFormatting('es');
  await AuthController.i.restore();

  runApp(const StockBarApp());
}

class StockBarApp extends StatelessWidget {
  const StockBarApp({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<AppPalette>(
        valueListenable: selectedPalette,
        builder: (_, palette, __) => AnimatedBuilder(
          animation: AuthController.i,
          builder: (_, __) {
            final auth = AuthController.i;
            return MaterialApp(
              title: 'Stock Bar',
              locale: const Locale('es'),
              supportedLocales: const [Locale('es')],
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              theme: palette.light,
              darkTheme: palette.dark,
              home: !auth.isSignedIn
                  ? const AuthScreen()
                  : auth.mustChangePassword
                      ? const ForcedPasswordScreen()
                      : const HomeScreen(),
            );
          },
        ),
      );
}
