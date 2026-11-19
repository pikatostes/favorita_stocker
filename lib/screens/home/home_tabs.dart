import 'package:flutter/material.dart';

import '../../shifts.dart';
import '../../widgets/app_navigation.dart';

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
