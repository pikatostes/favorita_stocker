import 'package:flutter/material.dart';
import '../auth_controller.dart';
import '../shifts.dart';
import 'registro.dart';
import 'productos.dart';
import 'prevision.dart';
import 'calendario.dart';
import 'turnos.dart';
import 'cuenta.dart';

/// Pestañas de la aplicación. Las marcadas como [adminOnly] solo se muestran
/// cuando el usuario tiene el rol [UserRole.admin].
enum HomeTab {
  list('Lista', Icons.edit_note),
  forecast('Previsión', Icons.insights),
  shifts('Turnos', Icons.groups),
  calendar('Calendario', Icons.event_available, adminOnly: true),
  products('Productos', Icons.liquor, adminOnly: true),
  account('Cuenta', Icons.account_circle_outlined);

  final String label;
  final IconData icon;
  final bool adminOnly;

  const HomeTab(this.label, this.icon, {this.adminOnly = false});
}

/// Pestañas visibles para [role]. Los empleados no ven Calendario ni Productos.
List<HomeTab> visibleHomeTabs(UserRole role) => [
      for (final tab in HomeTab.values)
        if (!tab.adminOnly || role == UserRole.admin) tab,
    ];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  HomeTab _tab = HomeTab.list;

  @override
  void initState() {
    super.initState();
    AuthController.i.addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    AuthController.i.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    if (!mounted) return;
    final role = AuthController.i.user?.role ?? UserRole.employee;
    final tabs = visibleHomeTabs(role);
    setState(() {
      // Si el usuario deja de ser admin mientras está en una pestaña
      // restringida, vuelve a la primera pestaña disponible.
      if (!tabs.contains(_tab)) _tab = HomeTab.list;
    });
  }

  Widget _pageFor(HomeTab tab) => switch (tab) {
        HomeTab.list => const RegistroScreen(),
        HomeTab.forecast => const PrevisionScreen(),
        HomeTab.shifts => const TurnosScreen(),
        HomeTab.calendar => const CalendarioScreen(),
        HomeTab.products => const ProductosScreen(),
        HomeTab.account => const CuentaScreen(),
      };

  @override
  Widget build(BuildContext context) {
    final role = AuthController.i.user?.role ?? UserRole.employee;
    final tabs = visibleHomeTabs(role);
    final selected = tabs.contains(_tab) ? tabs.indexOf(_tab) : 0;
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: selected,
          children: [for (final tab in tabs) _pageFor(tab)],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: (i) => setState(() => _tab = tabs[i]),
        destinations: [
          for (final tab in tabs)
            NavigationDestination(icon: Icon(tab.icon), label: tab.label),
        ],
      ),
    );
  }
}
