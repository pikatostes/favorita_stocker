import 'package:flutter/material.dart';
import '../../widgets/app_logo.dart';
import 'calendario.dart';
import 'inventario.dart';
import 'productos.dart';

/// Pestañas internas de la zona de administración.
enum AdminTab {
  calendar('Calendario'),
  products('Productos'),
  inventory('Inventario');

  final String label;

  const AdminTab(this.label);
}

/// Zona de administración: agrupa Calendario, Productos e Inventario en una
/// sola pestaña principal, con pestañas internas.
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: AdminTab.values.length,
        child: Scaffold(
          appBar: AppBar(
            title: const AppLogo(),
            bottom: TabBar(
              tabs: [
                for (final tab in AdminTab.values) Tab(text: tab.label),
              ],
            ),
          ),
          body: const TabBarView(
            children: [
              CalendarioScreen(embedded: true),
              ProductosScreen(embedded: true),
              InventarioScreen(embedded: true),
            ],
          ),
        ),
      );
}
