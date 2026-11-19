import 'package:flutter/material.dart';

/// Construye el contenido de una pestaña de [TabBarView] solo cuando pasa a
/// estar activa.
///
/// [TabBarView] monta por adelantado la página visible y la adyacente. Eso
/// hace que, al entrar en una pantalla con pestañas, se lancen las consultas
/// de pestañas que el usuario todavía no ha abierto. Al envolver cada hijo con
/// [LazyTab] el contenido no se crea hasta que su pestaña se selecciona. A
/// partir de ahí la pestaña se mantiene viva (keep-alive): conserva su estado y
/// no repite su primera carga al volver a ella.
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
  Widget build(BuildContext context) {
    if (!_active) return const SizedBox.shrink();
    // Una vez abierta, la pestaña se mantiene viva: conserva su estado y evita
    // repetir la carga al volver a ella.
    return _KeepAliveTab(child: widget.builder(context));
  }
}

/// Envoltorio que pide al [TabBarView] no destruir esta página al cambiar de
/// pestaña.
///
/// [LazyTab] evita construir pestañas que aún no se han abierto; este envoltorio
/// evita que las ya abiertas se reciclen y tengan que volver a cargar sus datos.
class _KeepAliveTab extends StatefulWidget {
  final Widget child;

  const _KeepAliveTab({required this.child});

  @override
  State<_KeepAliveTab> createState() => _KeepAliveTabState();
}

class _KeepAliveTabState extends State<_KeepAliveTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
