import 'package:flutter/material.dart';

import '../auth_controller.dart';
import '../shifts.dart';
import '../widgets/app_navigation.dart';
import '../widgets/app_ui.dart';
import 'admin/admin.dart';
import 'cuenta.dart';
import 'home/home_dashboard.dart';
import 'registro.dart';
import 'turnos.dart';

/// Pestañas de la aplicación. Las marcadas como [adminOnly] solo se muestran
/// cuando el usuario tiene el rol [UserRole.admin].
enum HomeTab {
  start(
    'Inicio',
    Icons.home_outlined,
    selectedIcon: Icons.home_rounded,
    group: AppNavGroup.operation,
  ),
  list(
    'Lista',
    Icons.edit_note_outlined,
    selectedIcon: Icons.edit_note,
    group: AppNavGroup.operation,
  ),
  shifts(
    'Turnos',
    Icons.groups_outlined,
    selectedIcon: Icons.groups,
    group: AppNavGroup.operation,
  ),
  admin(
    'Admin',
    Icons.admin_panel_settings_outlined,
    selectedIcon: Icons.admin_panel_settings,
    group: AppNavGroup.management,
    adminOnly: true,
  ),
  account(
    'Cuenta',
    Icons.account_circle_outlined,
    selectedIcon: Icons.account_circle,
    group: AppNavGroup.account,
  );

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final AppNavGroup group;
  final bool adminOnly;

  const HomeTab(
    this.label,
    this.icon, {
    required this.selectedIcon,
    required this.group,
    this.adminOnly = false,
  });
}

/// Pestañas visibles para [role]. Los empleados no ven la zona de Admin.
List<HomeTab> visibleHomeTabs(UserRole role) => [
      for (final tab in HomeTab.values)
        if (!tab.adminOnly || role == UserRole.admin) tab,
    ];

/// Distribución de la navegación principal. Se conserva este punto de entrada
/// para las pruebas y para documentar el comportamiento, pero la decisión real
/// depende solo del ancho disponible (nunca de la plataforma).
enum HomeNavigationMode { bottomBar, rail, sidebar }

HomeNavigationMode homeNavigationMode({
  bool isWeb = false,
  required double width,
}) =>
    switch (appNavigationModeForWidth(width)) {
      AppNavigationMode.bottomBar => HomeNavigationMode.bottomBar,
      AppNavigationMode.rail => HomeNavigationMode.rail,
      AppNavigationMode.sidebar => HomeNavigationMode.sidebar,
    };

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
