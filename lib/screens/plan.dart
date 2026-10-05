import 'package:flutter/material.dart';
import 'registro.dart';
import 'productos.dart';
import 'calendario.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  final _pages = const [
    RegistroScreen(),
    PrevisionScreen(),
    CalendarioScreen(),
    ProductosScreen(),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(child: IndexedStack(index: _tab, children: _pages)),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.edit_note), label: 'Lista'),
            NavigationDestination(icon: Icon(Icons.insights), label: 'Previsión'),
            NavigationDestination(
                icon: Icon(Icons.event_available), label: 'Calendario'),
            NavigationDestination(icon: Icon(Icons.liquor), label: 'Productos'),
          ],
        ),
      );
}
