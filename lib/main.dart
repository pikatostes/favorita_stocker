import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'db.dart';
import 'seed.dart';
import 'screens/home.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es');
  await Db.i.seedIfEmpty(initialProducts);
  await Db.i.purgeOld(); // borra lo que supere los 2 años de histórico
  runApp(const StockBarApp());
}

class StockBarApp extends StatelessWidget {
  const StockBarApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Stock Bar',
        locale: const Locale('es'),
        supportedLocales: const [Locale('es')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: ThemeData(colorSchemeSeed: Colors.amber, useMaterial3: true),
        darkTheme: ThemeData(
            colorSchemeSeed: Colors.amber,
            brightness: Brightness.dark,
            useMaterial3: true),
        home: const HomeScreen(),
      );
}
