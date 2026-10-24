import 'package:flutter/material.dart';
import '../widgets/app_logo.dart';
import 'calendario.dart';
import 'inventario.dart';
import 'productos.dart';

/// Zona de administración: agrupa Calendario, Productos e Inventario en una
/// sola pestaña principal, con pestañas internas.
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const AppLogo(),
          bottom: TabBar(
            controller: _tabs,
            tabs: const [
              Tab(text: 'Calendario'),
              Tab(text: 'Productos'),
              Tab(text: 'Inventario'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabs,
          children: const [
            CalendarioScreen(embedded: true),
            ProductosScreen(embedded: true),
            InventarioScreen(embedded: true),
          ],
        ),
      );
}
