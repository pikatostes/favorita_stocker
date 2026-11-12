import 'package:flutter/material.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/lazy_tab.dart';
import '../incidents.dart';
import 'calendario.dart';
import 'inventario.dart';
import 'productos.dart';

/// Pestañas internas de la zona de administración.
enum AdminTab {
  calendar('Calendario'),
  products('Productos'),
  inventory('Inventario'),
  incidents('Incidencias');

  final String label;

  const AdminTab(this.label);
}

/// Zona de administración: agrupa Calendario, Productos, Inventario e
/// Incidencias en una sola pestaña principal, con pestañas internas.
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: AdminTab.values.length,
        child: Scaffold(
          appBar: AppBar(
            title: const AppLogo(),
            bottom: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                for (final tab in AdminTab.values) Tab(text: tab.label),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              LazyTab(
                index: AdminTab.calendar.index,
                builder: (_) => const CalendarioScreen(embedded: true),
              ),
              LazyTab(
                index: AdminTab.products.index,
                builder: (_) => const ProductosScreen(embedded: true),
              ),
              LazyTab(
                index: AdminTab.inventory.index,
                builder: (_) => const InventarioScreen(embedded: true),
              ),
              LazyTab(
                index: AdminTab.incidents.index,
                builder: (_) => const IncidentsScreen(embedded: true),
              ),
            ],
          ),
        ),
      );
}
