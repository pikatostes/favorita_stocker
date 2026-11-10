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
  await initializeDateFormatting('es');

  // Sin las claves no se puede hablar con el backend. En vez de lanzar una
  // excepción (que en web deja la página en blanco), se muestra una pantalla
  // que explica cómo compilar correctamente.
  if (_supabaseUrl.isEmpty || _supabaseKey.isEmpty) {
    runApp(const _MissingConfigApp());
    return;
  }

  await Supabase.initialize(
    url: _supabaseUrl,
    publishableKey: _supabaseKey,
  );
  await AuthController.i.restore();

  runApp(const StockBarApp());
}

/// Pantalla que sustituye a la app cuando la compilación no trae las claves.
///
/// Es el caso típico de un despliegue web (Vercel, Netlify…) que ejecuta
/// `flutter build web` sin `--dart-define`.
class _MissingConfigApp extends StatelessWidget {
  const _MissingConfigApp();

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<AppPalette>(
        valueListenable: selectedPalette,
        builder: (_, palette, __) => MaterialApp(
          title: 'La Favorita - Stock Bar',
          debugShowCheckedModeBanner: false,
          locale: const Locale('es'),
          supportedLocales: const [Locale('es')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: palette.light,
          darkTheme: palette.dark,
          home: const _MissingConfigScreen(),
        ),
      );
}

/// Contenido de la pantalla de configuración ausente. Usa el `Theme` ya
/// resuelto por [MaterialApp] para respetar el modo claro/oscuro del sistema.
class _MissingConfigScreen extends StatelessWidget {
  const _MissingConfigScreen();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final missing = [
      if (_supabaseUrl.isEmpty) 'SUPABASE_URL',
      if (_supabaseKey.isEmpty) 'SUPABASE_PUBLISHABLE_KEY',
    ].join(' y ');

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.settings_ethernet,
                            color: theme.colorScheme.error,
                            size: 32,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Falta configurar Supabase',
                              style: theme.textTheme.headlineSmall,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Esta compilación no incluye $missing, así que la app '
                        'no puede conectarse a la base de datos.',
                        style: theme.textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 20),
                      Text('En local', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 6),
                      const _Command(
                        'flutter run -d windows '
                        '--dart-define-from-file=env.json',
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'En Vercel (u otro CI)',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Define SUPABASE_URL y SUPABASE_PUBLISHABLE_KEY en el '
                        'proyecto y pásalas al compilar:',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 6),
                      const _Command(
                        'flutter build web --release \\\n'
                        '  --dart-define=SUPABASE_URL="\$SUPABASE_URL" \\\n'
                        '  --dart-define=SUPABASE_PUBLISHABLE_KEY="\$SUPABASE_PUBLISHABLE_KEY"',
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Solo hace falta la clave publicable. La clave secreta '
                        '(service_role) nunca se usa en el cliente. El resto '
                        'de la puesta en marcha está en supabase/README.md.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bloque de código con fondo tenue, para copiar los comandos.
class _Command extends StatelessWidget {
  final String text;
  const _Command(this.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: SelectableText(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontFamily: 'monospace',
          height: 1.5,
        ),
      ),
    );
  }
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
              title: 'La Favorita - Stock Bar',
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
