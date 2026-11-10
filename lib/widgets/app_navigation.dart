import 'package:flutter/material.dart';

import '../app_design.dart';
import '../shifts.dart';
import 'app_logo.dart';
import 'user_avatar.dart';

/// Grupo al que pertenece un destino del menú principal.
enum AppNavGroup {
  operation('Operación'),
  management('Administración'),
  account('Cuenta');

  final String label;

  const AppNavGroup(this.label);
}

/// Un destino de la navegación principal.
class AppDestination {
  final String id;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final AppNavGroup group;

  const AppDestination({
    required this.id,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.group,
  });
}

/// Distribución de la navegación derivada únicamente del ancho disponible.
enum AppNavigationMode { bottomBar, rail, sidebar }

AppNavigationMode appNavigationModeForWidth(double width) {
  if (width < AppBreakpoints.mobileMax) return AppNavigationMode.bottomBar;
  if (width < AppBreakpoints.desktopMin) return AppNavigationMode.rail;
  return AppNavigationMode.sidebar;
}

/// Armazón común de la aplicación.
///
/// - Menos de 600 px: barra inferior con cinco destinos e indicador claro.
/// - 600–1023 px: rail lateral compacto con iconos y etiquetas.
/// - 1024 px o más: sidebar vertical, agrupado y colapsable, con el perfil y
///   las opciones secundarias en la parte inferior.
class AppNavigationShell extends StatefulWidget {
  final List<AppDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Widget child;
  final AppUser? user;
  final VoidCallback? onAccount;
  final Future<void> Function()? onLogout;

  const AppNavigationShell({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    required this.child,
    this.user,
    this.onAccount,
    this.onLogout,
  });

  @override
  State<AppNavigationShell> createState() => _AppNavigationShellState();
}

class _AppNavigationShellState extends State<AppNavigationShell> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final mode = appNavigationModeForWidth(constraints.maxWidth);
          if (mode == AppNavigationMode.bottomBar) {
            return _buildBottomNavigation(context);
          }
          return _buildSideNavigation(context, mode);
        },
      );

  Widget _buildBottomNavigation(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(bottom: false, child: widget.child),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          border: Border(
            top: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
        ),
        child: SafeArea(
          top: false,
          child: NavigationBar(
            selectedIndex: widget.selectedIndex,
            onDestinationSelected: widget.onSelected,
            destinations: [
              for (final destination in widget.destinations)
                NavigationDestination(
                  icon: Icon(destination.icon),
                  selectedIcon: Icon(destination.selectedIcon),
                  label: destination.label,
                  tooltip: destination.label,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSideNavigation(
    BuildContext context,
    AppNavigationMode mode,
  ) {
    final isSidebar = mode == AppNavigationMode.sidebar;
    final expanded = isSidebar && _expanded;
    final width = isSidebar
        ? (expanded
            ? AppBreakpoints.sidebarWidth
            : AppBreakpoints.sidebarCollapsedWidth)
        : AppBreakpoints.railWidth;

    final accountIndex = widget.destinations
        .indexWhere((destination) => destination.group == AppNavGroup.account);
    final mainDestinations = isSidebar
        ? [
            for (var i = 0; i < widget.destinations.length; i++)
              if (i != accountIndex)
                (index: i, destination: widget.destinations[i]),
          ]
        : [
            for (var i = 0; i < widget.destinations.length; i++)
              (index: i, destination: widget.destinations[i]),
          ];

    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: width,
            child: Material(
              color: Theme.of(context).colorScheme.surfaceContainerLowest,
              child: SafeArea(
                right: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SidebarHeader(
                      expanded: expanded,
                      rail: !isSidebar,
                      onToggle: isSidebar
                          ? () => setState(() => _expanded = !_expanded)
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.symmetric(
                          horizontal: expanded ? AppSpacing.md : AppSpacing.sm,
                        ),
                        children: [
                          if (expanded)
                            for (var i = 0;
                                i < mainDestinations.length;
                                i++) ...[
                              if (i == 0 ||
                                  mainDestinations[i].destination.group !=
                                      mainDestinations[i - 1].destination.group)
                                _GroupLabel(
                                  label: mainDestinations[i]
                                      .destination
                                      .group
                                      .label,
                                ),
                              _SidebarItem(
                                destination: mainDestinations[i].destination,
                                selected: mainDestinations[i].index ==
                                    widget.selectedIndex,
                                expanded: true,
                                onTap: () => widget.onSelected(
                                  mainDestinations[i].index,
                                ),
                              ),
                            ]
                          else
                            for (final item in mainDestinations)
                              _RailItem(
                                destination: item.destination,
                                selected: item.index == widget.selectedIndex,
                                onTap: () => widget.onSelected(item.index),
                              ),
                        ],
                      ),
                    ),
                    if (isSidebar) ...[
                      const Divider(height: 1),
                      _ProfileFooter(
                        user: widget.user,
                        expanded: expanded,
                        accountSelected: accountIndex >= 0 &&
                            accountIndex == widget.selectedIndex,
                        onAccount: widget.onAccount,
                        onLogout: widget.onLogout,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ),
              ),
            ),
          ),
          VerticalDivider(
            width: 1,
            thickness: 1,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          Expanded(child: SafeArea(child: widget.child)),
        ],
      ),
    );
  }
}

class _SidebarHeader extends StatelessWidget {
  final bool expanded;
  final bool rail;
  final VoidCallback? onToggle;

  const _SidebarHeader({
    required this.expanded,
    required this.rail,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        expanded ? AppSpacing.lg : AppSpacing.sm,
        AppSpacing.lg,
        expanded ? AppSpacing.sm : AppSpacing.sm,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          if (expanded)
            const Expanded(child: AppLogo(height: 30))
          else
            Expanded(
              child: Center(
                child: Tooltip(
                  message: 'La Favorita',
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(AppRadii.md),
                    ),
                    child: Icon(
                      Icons.local_bar,
                      size: 21,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
            ),
          if (onToggle != null)
            IconButton(
              tooltip: expanded ? 'Contraer menú' : 'Expandir menú',
              onPressed: onToggle,
              icon: Icon(
                expanded ? Icons.menu_open : Icons.menu,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  final String label;

  const _GroupLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final AppDestination destination;
  final bool selected;
  final bool expanded;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.destination,
    required this.selected,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!expanded) {
      return _RailItem(
        destination: destination,
        selected: selected,
        onTap: onTap,
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color:
            selected ? theme.colorScheme.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadii.md),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 11,
            ),
            child: Row(
              children: [
                Icon(
                  selected ? destination.selectedIcon : destination.icon,
                  size: 21,
                  color: selected
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    destination.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: selected
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onSurfaceVariant,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                if (selected)
                  Container(
                    width: 4,
                    height: 18,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  final AppDestination destination;
  final bool selected;
  final VoidCallback onTap;

  const _RailItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: destination.label,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Material(
          color: selected
              ? theme.colorScheme.primaryContainer
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadii.md),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: AppSpacing.sm,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    selected ? destination.selectedIcon : destination.icon,
                    size: 22,
                    color: selected
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    destination.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: selected
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onSurfaceVariant,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileFooter extends StatelessWidget {
  final AppUser? user;
  final bool expanded;
  final bool accountSelected;
  final VoidCallback? onAccount;
  final Future<void> Function()? onLogout;

  const _ProfileFooter({
    required this.user,
    required this.expanded,
    required this.accountSelected,
    this.onAccount,
    this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = user?.fullName.trim().isNotEmpty == true
        ? user!.fullName.trim()
        : 'Mi cuenta';
    final role = user?.jobRole == null
        ? (user?.role.label ?? 'Sin sesión')
        : '${user!.jobRole!.name} · ${user!.jobRole!.floor.label}';

    if (!expanded) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        child: Column(
          children: [
            Tooltip(
              message: name,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onAccount,
                child: UserAvatar(
                  user: user,
                  radius: 20,
                  backgroundColor: accountSelected
                      ? theme.colorScheme.primaryContainer
                      : theme.colorScheme.surfaceContainerHigh,
                  foregroundColor: accountSelected
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onSurface,
                ),
              ),
            ),
            if (onLogout != null)
              IconButton(
                tooltip: 'Cerrar sesión',
                onPressed: () => onLogout!(),
                icon: const Icon(Icons.logout, size: 19),
              ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: accountSelected
                ? theme.colorScheme.primaryContainer
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadii.md),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onAccount,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Row(
                  children: [
                    UserAvatar(
                      user: user,
                      radius: 19,
                      backgroundColor: theme.colorScheme.surfaceContainerHigh,
                      foregroundColor: theme.colorScheme.onSurface,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: accountSelected
                                  ? theme.colorScheme.onPrimaryContainer
                                  : theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            role,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: accountSelected
                                  ? theme.colorScheme.onPrimaryContainer
                                      .withValues(alpha: 0.8)
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (onLogout != null)
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: 'Cerrar sesión',
                onPressed: () => onLogout!(),
                icon: const Icon(Icons.logout, size: 19),
              ),
            ),
        ],
      ),
    );
  }
}
