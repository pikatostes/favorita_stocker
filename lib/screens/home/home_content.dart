import 'package:flutter/material.dart';

import '../../app_design.dart';
import '../../data/home_data.dart';
import '../../shifts.dart';
import '../../widgets/app_ui.dart';
import 'widgets/admin_planning_card.dart';
import 'widgets/admin_tonight_card.dart';
import 'widgets/employee_tonight_card.dart';
import 'widgets/home_header.dart';
import 'widgets/incidents_card.dart';
import 'widgets/maintenance_list_card.dart';
import 'widgets/my_day_card.dart';

/// Composición visual del panel de Inicio.
///
/// Decide qué tarjetas se muestran y cómo se distribuyen según el rol y el
/// ancho disponible. No carga datos ni ejecuta acciones: las recibe del
/// `HomeDashboard`, lo que permite probar y reutilizar cada tarjeta por
/// separado.
class HomeContent extends StatelessWidget {
  final HomeData data;
  final AppUser? user;
  final bool working;
  final VoidCallback onGenerate;
  final VoidCallback onPublish;
  final ValueChanged<NightListSummary> onOpenPlan;

  const HomeContent({
    super.key,
    required this.data,
    required this.user,
    required this.working,
    required this.onGenerate,
    required this.onPublish,
    required this.onOpenPlan,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= AppBreakpoints.twoColumnContent;
        final padding = _pagePadding(constraints.maxWidth);

        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            AppContentFrame(
              padding: padding.copyWith(bottom: AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  HomeHeader(data: data, user: user),
                  if (user?.isMaintenance == true) ...[
                    MaintenanceListCard(data: data, onOpen: onOpenPlan),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  _roleCards(wide: wide),
                ],
              ),
            ),
            // Tarjeta separada del resto para que el listado de incidencias
            // solo monte su estado (y consulte la BD) cuando entra en
            // pantalla, no al abrir Inicio.
            AppContentFrame(
              padding: padding.copyWith(top: 0),
              child: const IncidentsCard(),
            ),
          ],
        );
      },
    );
  }

  /// Tarjetas principales del rol: admin ve planificación; el resto, su día.
  Widget _roleCards({required bool wide}) {
    if (user?.role == UserRole.admin) {
      final tonight = AdminTonightCard(data: data);
      final planning = AdminPlanningCard(
        data: data,
        working: working,
        onGenerate: onGenerate,
        onPublish: onPublish,
      );
      return wide
          ? _HomeColumns(left: tonight, right: planning)
          : _StackedCards(children: [tonight, planning]);
    }

    final myDay = MyDayCard(data: data, user: user);
    final tonight = EmployeeTonightCard(data: data);
    return wide
        ? _HomeColumns(
            left: myDay,
            right: tonight,
            leftFlex: 2,
            rightFlex: 3,
          )
        : _StackedCards(children: [myDay, tonight]);
  }

  EdgeInsets _pagePadding(double width) {
    final horizontal =
        width >= AppBreakpoints.tabletMin ? AppSpacing.xl : AppSpacing.lg;
    return EdgeInsets.fromLTRB(
      horizontal,
      AppSpacing.lg,
      horizontal,
      AppSpacing.xl,
    );
  }
}

/// Dos columnas equilibradas para escritorio, con separación consistente.
class _HomeColumns extends StatelessWidget {
  final Widget left;
  final Widget right;
  final int leftFlex;
  final int rightFlex;

  const _HomeColumns({
    required this.left,
    required this.right,
    this.leftFlex = 3,
    this.rightFlex = 2,
  });

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: leftFlex, child: left),
          const SizedBox(width: AppSpacing.lg),
          Expanded(flex: rightFlex, child: right),
        ],
      );
}

/// Tarjetas apiladas con la separación vertical habitual del panel.
class _StackedCards extends StatelessWidget {
  final List<Widget> children;

  const _StackedCards({required this.children});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < children.length; index++) ...[
            if (index > 0) const SizedBox(height: AppSpacing.lg),
            children[index],
          ],
        ],
      );
}
