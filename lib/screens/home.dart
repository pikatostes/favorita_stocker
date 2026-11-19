import 'package:flutter/material.dart';

import '../auth_controller.dart';
import '../shifts.dart';
import '../widgets/app_navigation.dart';
import '../widgets/app_ui.dart';
import 'admin/admin.dart';
import 'cuenta.dart';
import 'home/home_dashboard.dart';
import 'home/home_tabs.dart';
import 'registro.dart';
import 'turnos.dart';

// La configuración de pestañas se mantiene exportada para que el resto de la
// app (y las pruebas) sigan importando solo esta pantalla.
export 'home/home_tabs.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  HomeTab _tab = HomeTab.start;

  /// Pestañas que ya se han abierto alguna vez. El resto no se construye, así
  /// que no lanza sus consultas hasta que el usuario las necesita.
  final Set<HomeTab> _built = {HomeTab.start};

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
      // restringida, vuelve a la pestaña de Inicio.
      if (!tabs.contains(_tab)) _tab = HomeTab.start;
    });
  }

  void _goTo(HomeTab tab) {
    final role = AuthController.i.user?.role ?? UserRole.employee;
    if (!visibleHomeTabs(role).contains(tab)) return;
    setState(() {
      _tab = tab;
      _built.add(tab);
    });
  }

  Future<void> _logout() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Cerrar sesión',
      message: '¿Quieres salir de tu cuenta?',
      confirmLabel: 'Cerrar sesión',
    );
    if (ok) await AuthController.i.logout();
  }

  Widget _pageFor(HomeTab tab) => switch (tab) {
        HomeTab.start => const HomeDashboard(),
        HomeTab.list => const RegistroScreen(),
        HomeTab.shifts => const TurnosScreen(),
        HomeTab.admin => const AdminScreen(),
        HomeTab.account => const CuentaScreen(),
      };

  @override
  Widget build(BuildContext context) {
    final role = AuthController.i.user?.role ?? UserRole.employee;
    final tabs = visibleHomeTabs(role);
    final selected = tabs.contains(_tab) ? tabs.indexOf(_tab) : 0;
    final pages = IndexedStack(
      index: selected,
      children: [
        for (final tab in tabs)
          if (_built.contains(tab))
            KeyedSubtree(key: ValueKey(tab), child: _pageFor(tab))
          else
            const SizedBox.shrink(),
      ],
    );

    return AppNavigationShell(
      selectedIndex: selected,
      onSelected: (index) => _goTo(tabs[index]),
      destinations: [
        for (final tab in tabs)
          AppDestination(
            id: tab.name,
            label: tab.label,
            icon: tab.icon,
            selectedIcon: tab.selectedIcon,
            group: tab.group,
          ),
      ],
      user: AuthController.i.user,
      onAccount: () => _goTo(HomeTab.account),
      onLogout: _logout,
      child: pages,
    );
  }
}
