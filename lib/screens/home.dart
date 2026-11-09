import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../auth_controller.dart';
import '../shifts.dart';
import '../widgets/app_logo.dart';
import 'admin/admin.dart';
import 'cuenta.dart';
import 'home/home_dashboard.dart';
import 'registro.dart';
import 'turnos.dart';

/// Pestañas de la aplicación. Las marcadas como [adminOnly] solo se muestran
/// cuando el usuario tiene el rol [UserRole.admin].
enum HomeTab {
  start('Inicio', Icons.home_outlined),
  list('Lista', Icons.edit_note),
  shifts('Turnos', Icons.groups),
  admin('Admin', Icons.admin_panel_settings, adminOnly: true),
  account('Cuenta', Icons.account_circle_outlined);

  final String label;
  final IconData icon;
  final bool adminOnly;

  const HomeTab(this.label, this.icon, {this.adminOnly = false});
}

/// Pestañas visibles para [role]. Los empleados no ven la zona de Admin.
List<HomeTab> visibleHomeTabs(UserRole role) => [
      for (final tab in HomeTab.values)
        if (!tab.adminOnly || role == UserRole.admin) tab,
    ];

/// Forma de la navegación principal según la plataforma y el ancho disponible.
enum HomeNavigationMode {
  /// Barra inferior: móvil nativo en vertical, donde una barra lateral
  /// robaría demasiado ancho al contenido.
  bottomBar,

  /// Menú lateral compacto, solo con iconos: web en ventanas estrechas.
  compactRail,

  /// Menú lateral con la etiqueta debajo del icono.
  rail,

  /// Menú lateral extendido, con icono y etiqueta en la misma línea.
  extendedRail,
}

/// Ancho a partir del cual una app nativa deja la barra inferior y usa el menú
/// lateral (tabletas y escritorio).
const double kHomeRailBreakpoint = 840;

/// Ancho a partir del cual la web muestra el menú lateral completo en lugar
/// del compacto.
const double kHomeRailLabelsBreakpoint = 600;

/// Ancho a partir del cual el menú lateral enseña las etiquetas al lado del
/// icono en lugar de debajo.
const double kHomeExtendedRailBreakpoint = 1080;

/// Decide la navegación a partir de la plataforma y del ancho de la ventana.
///
/// En web siempre se usa un menú lateral a la izquierda (compacto si la
/// ventana es estrecha). En el resto de plataformas se mantiene la barra
/// inferior mientras no haya ancho suficiente para el menú lateral.
HomeNavigationMode homeNavigationMode({
  required bool isWeb,
  required double width,
}) {
  if (!isWeb && width < kHomeRailBreakpoint) {
    return HomeNavigationMode.bottomBar;
  }
  if (width >= kHomeExtendedRailBreakpoint) {
    return HomeNavigationMode.extendedRail;
  }
  if (isWeb && width < kHomeRailLabelsBreakpoint) {
    return HomeNavigationMode.compactRail;
  }
  return HomeNavigationMode.rail;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  HomeTab _tab = HomeTab.start;

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
    setState(() => _tab = tab);
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
    final mode = homeNavigationMode(
      isWeb: kIsWeb,
      width: MediaQuery.sizeOf(context).width,
    );
    final pages = IndexedStack(
      index: selected,
      children: [for (final tab in tabs) _pageFor(tab)],
    );

    // En web (y en ventanas anchas) el menú vive a la izquierda; en móvil se
    // conserva la barra inferior habitual.
    if (mode == HomeNavigationMode.bottomBar) {
      return Scaffold(
        body: SafeArea(child: pages),
        bottomNavigationBar: NavigationBar(
          selectedIndex: selected,
          onDestinationSelected: (i) => _goTo(tabs[i]),
          destinations: [
            for (final tab in tabs)
              NavigationDestination(icon: Icon(tab.icon), label: tab.label),
          ],
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          SafeArea(
            right: false,
            child: _SideNavigation(
              mode: mode,
              tabs: tabs,
              selectedIndex: selected,
              onSelected: (i) => _goTo(tabs[i]),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: SafeArea(child: pages)),
        ],
      ),
    );
  }
}

/// Menú lateral de la navegación principal.
///
/// Se adapta al ancho: en ventanas estrechas solo muestra iconos, luego las
/// etiquetas debajo y, cuando hay sitio, el formato extendido con la etiqueta
/// al lado del icono.
class _SideNavigation extends StatelessWidget {
  final HomeNavigationMode mode;
  final List<HomeTab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _SideNavigation({
    required this.mode,
    required this.tabs,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extended = mode == HomeNavigationMode.extendedRail;
    final compact = mode == HomeNavigationMode.compactRail;

    return NavigationRail(
      selectedIndex: selectedIndex,
      onDestinationSelected: onSelected,
      extended: extended,
      minWidth: compact ? 64 : 80,
      labelType: extended || compact
          ? NavigationRailLabelType.none
          : NavigationRailLabelType.all,
      leading: Padding(
        padding:
            EdgeInsets.fromLTRB(extended ? 16 : 8, 16, extended ? 16 : 8, 8),
        child: extended
            ? const AppLogo(height: 32)
            : CircleAvatar(
                radius: 18,
                backgroundColor: theme.colorScheme.primaryContainer,
                foregroundColor: theme.colorScheme.onPrimaryContainer,
                child: const Icon(Icons.local_bar, size: 20),
              ),
      ),
      destinations: [
        for (final tab in tabs)
          NavigationRailDestination(
            icon: Icon(tab.icon),
            selectedIcon: Icon(tab.icon, color: theme.colorScheme.primary),
            label: Text(tab.label),
            padding: compact
                ? const EdgeInsets.symmetric(vertical: 6)
                : const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          ),
      ],
    );
  }
}
