import 'package:flutter/material.dart';

/// Construye el contenido de una pestaña de [TabBarView] solo cuando pasa a
/// estar activa.
///
/// [TabBarView] monta por adelantado la página visible y la adyacente. Eso
/// hace que, al entrar en una pantalla con pestañas, se lancen las consultas
/// de pestañas que el usuario todavía no ha abierto. Al envolver cada hijo con
/// [LazyTab] el contenido no se crea hasta que su pestaña se selecciona; a
/// partir de ahí se construye con normalidad (sujeto al reciclado de páginas
/// que hace [TabBarView]).
class LazyTab extends StatefulWidget {
  /// Posición de la pestaña dentro del [TabController].
  final int index;

  /// Contenido real de la pestaña.
  final WidgetBuilder builder;

  /// Controlador de las pestañas. Si es `null` se usa el
  /// [DefaultTabController] más cercano.
  final TabController? controller;

  const LazyTab({
    super.key,
    required this.index,
    required this.builder,
    this.controller,
  });

  @override
  State<LazyTab> createState() => _LazyTabState();
}

class _LazyTabState extends State<LazyTab> {
  TabController? _controller;
  bool _active = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _attach(widget.controller ?? DefaultTabController.maybeOf(context));
  }

  @override
  void didUpdateWidget(covariant LazyTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      _detach();
      _active = false;
      _attach(widget.controller);
      return;
    }
    if (oldWidget.controller != widget.controller) {
      _detach();
      _attach(widget.controller);
    }
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  void _attach(TabController? controller) {
    if (controller == _controller) {
      _activateIfSelected();
      return;
    }
    _detach();
    _controller = controller;
    // Si ya se había activado no hace falta volver a escuchar sus cambios.
    if (_active) return;
    _controller?.addListener(_activateIfSelected);
    _activateIfSelected();
  }

  void _detach() {
    _controller?.removeListener(_activateIfSelected);
    _controller = null;
  }

  void _activateIfSelected() {
    final controller = _controller;
    if (_active || controller == null || controller.index != widget.index) {
      return;
    }
    // Una vez visible ya no hace falta seguir escuchando: la pestaña se queda
    // montada para conservar su estado.
    _detach();
    setState(() => _active = true);
  }

  @override
  Widget build(BuildContext context) =>
      _active ? widget.builder(context) : const SizedBox.shrink();
}
