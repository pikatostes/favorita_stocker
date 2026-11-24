import 'package:flutter/material.dart';

import '../../widgets/app_logo.dart';
import '../../widgets/lazy_tab.dart';
import '../../auth_controller.dart';
import '../../shifts.dart';
import 'turnos/positions/positions_tab.dart';
import 'turnos/schedule/schedule_tab.dart';
import 'turnos/turnos_tabs.dart';
import 'turnos/users/users_tab.dart';

// Configuración y resumen de usuario exportados para que el resto de la app
// (y las pruebas) sigan importando solo esta pantalla.
export 'turnos/turnos_tabs.dart';
export 'turnos/users/user_summary.dart';

/// Pestaña "Turnos": horario mensual, usuarios y puestos.
class TurnosScreen extends StatefulWidget {
  const TurnosScreen({super.key});
  @override
  State<TurnosScreen> createState() => _TurnosScreenState();
}

class _TurnosScreenState extends State<TurnosScreen>
    with TickerProviderStateMixin {
  late bool _isAdmin;
  late TabController _tabs;

  bool get _hasAdminRole => AuthController.i.user?.role == UserRole.admin;

  @override
  void initState() {
    super.initState();
    _isAdmin = _hasAdminRole;
    _tabs = TabController(length: _isAdmin ? 3 : 2, vsync: this);
    AuthController.i.addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    AuthController.i.removeListener(_onAuthChanged);
    _tabs.dispose();
    super.dispose();
  }

  void _onAuthChanged() {
    if (!mounted) return;
    final isAdmin = _hasAdminRole;
    if (isAdmin == _isAdmin) return;

    final old = _tabs;
    final length = isAdmin ? 3 : 2;
    final nextIndex = old.index >= length ? 0 : old.index;
    setState(() {
      _isAdmin = isAdmin;
      _tabs = TabController(
        length: length,
        vsync: this,
        initialIndex: nextIndex,
      );
    });
    old.dispose();
  }

  Widget _pageFor(TurnoTab tab) => switch (tab) {
        TurnoTab.schedule => ScheduleTab(isAdmin: _isAdmin),
        TurnoTab.users => UsersTab(isAdmin: _isAdmin),
        TurnoTab.positions => const PositionsTab(),
      };

  @override
  Widget build(BuildContext context) {
    final tabs = visibleTurnoTabs(
      AuthController.i.user?.role ?? UserRole.employee,
    );
    return Scaffold(
      appBar: AppBar(
        title: const AppLogo(),
        bottom: TabBar(
          controller: _tabs,
          tabs: [for (final tab in tabs) Tab(text: tab.label)],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          for (final tab in tabs)
            LazyTab(
              index: tabs.indexOf(tab),
              controller: _tabs,
              builder: (_) => _pageFor(tab),
            ),
        ],
      ),
    );
  }
}
