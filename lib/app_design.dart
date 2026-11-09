import 'package:flutter/material.dart';

/// Puntos de corte y medidas compartidas de La Favorita Stocker.
///
/// Toda decisión responsive debe salir de aquí (o de los componentes que usan
/// estas constantes) para que la app se comporte igual en todas las pantallas.
abstract final class AppBreakpoints {
  /// Móvil: menos de 600 px.
  static const double mobileMax = 600;

  /// Tablet: de 600 px (incluido) a 1024 px (excluido).
  static const double tabletMin = 600;
  static const double tabletMax = 1024;

  /// Escritorio: 1024 px o más.
  static const double desktopMin = 1024;

  /// A partir de este ancho de contenido el dashboard usa dos columnas.
  static const double twoColumnContent = 900;

  /// Ancho máximo del contenido para no estirar tarjetas en monitores grandes.
  static const double contentMaxWidth = 1240;

  /// Ancho recomendado para pantallas de lectura/formularios.
  static const double formMaxWidth = 720;

  /// Ancho de la barra inferior en móvil (sin contar el área segura).
  static const double bottomBarHeight = 66;

  /// Ancho del menú lateral compacto (tablet).
  static const double railWidth = 88;

  /// Ancho del sidebar extendido y contraído en escritorio.
  static const double sidebarWidth = 256;
  static const double sidebarCollapsedWidth = 80;

  static bool isMobile(double width) => width < mobileMax;

  static bool isTablet(double width) =>
      width >= tabletMin && width < desktopMin;

  static bool isDesktop(double width) => width >= desktopMin;

  /// Máximo de columnas razonable para una rejilla de tarjetas.
  static int gridColumns(
    double width, {
    int min = 2,
    int max = 5,
    double minTileWidth = 160,
  }) {
    final columns = (width / minTileWidth).floor();
    return columns.clamp(min, max);
  }
}

/// Escala de espaciado basada en múltiplos de 4 px.
abstract final class AppSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
}

/// Radios compartidos para superficies, controles y píldoras.
abstract final class AppRadii {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 22;
  static const double pill = 999;
}

/// Medidas mínimas de interacción táctil.
abstract final class AppSizes {
  static const double touchTarget = 48;
  static const double controlHeight = 40;
  static const double inputHeight = 48;
  static const double avatar = 40;
  static const double productThumb = 48;
}

/// Colores semánticos que Material no incluye de serie (éxito, aviso, info).
///
/// Se registran como [ThemeExtension] para conservar el contraste en los dos
/// modos y no repartir colores sueltos por las pantallas.
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  final Color success;
  final Color successContainer;
  final Color onSuccessContainer;
  final Color warning;
  final Color warningContainer;
  final Color onWarningContainer;
  final Color info;
  final Color infoContainer;
  final Color onInfoContainer;

  const AppSemanticColors({
    required this.success,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.warning,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.info,
    required this.infoContainer,
    required this.onInfoContainer,
  });

  static const light = AppSemanticColors(
    success: Color(0xFF2F6B45),
    successContainer: Color(0xFFDCEFE3),
    onSuccessContainer: Color(0xFF1B4028),
    warning: Color(0xFF8A5A00),
    warningContainer: Color(0xFFFBE7C0),
    onWarningContainer: Color(0xFF4A2E00),
    info: Color(0xFF0A5C8C),
    infoContainer: Color(0xFFD7EAF5),
    onInfoContainer: Color(0xFF063B5B),
  );

  static const dark = AppSemanticColors(
    success: Color(0xFF8ED6A8),
    successContainer: Color(0xFF203A2A),
    onSuccessContainer: Color(0xFFC9F2D8),
    warning: Color(0xFFF2BE5C),
    warningContainer: Color(0xFF3A2A10),
    onWarningContainer: Color(0xFFFFE1A6),
    info: Color(0xFF7CC7F0),
    infoContainer: Color(0xFF113244),
    onInfoContainer: Color(0xFFC7E9FA),
  );

  static AppSemanticColors of(BuildContext context) =>
      Theme.of(context).extension<AppSemanticColors>() ??
      (Theme.of(context).brightness == Brightness.dark ? dark : light);

  @override
  AppSemanticColors copyWith({
    Color? success,
    Color? successContainer,
    Color? onSuccessContainer,
    Color? warning,
    Color? warningContainer,
    Color? onWarningContainer,
    Color? info,
    Color? infoContainer,
    Color? onInfoContainer,
  }) =>
      AppSemanticColors(
        success: success ?? this.success,
        successContainer: successContainer ?? this.successContainer,
        onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
        warning: warning ?? this.warning,
        warningContainer: warningContainer ?? this.warningContainer,
        onWarningContainer: onWarningContainer ?? this.onWarningContainer,
        info: info ?? this.info,
        infoContainer: infoContainer ?? this.infoContainer,
        onInfoContainer: onInfoContainer ?? this.onInfoContainer,
      );

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      success: Color.lerp(success, other.success, t)!,
      successContainer:
          Color.lerp(successContainer, other.successContainer, t)!,
      onSuccessContainer:
          Color.lerp(onSuccessContainer, other.onSuccessContainer, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningContainer:
          Color.lerp(warningContainer, other.warningContainer, t)!,
      onWarningContainer:
          Color.lerp(onWarningContainer, other.onWarningContainer, t)!,
      info: Color.lerp(info, other.info, t)!,
      infoContainer: Color.lerp(infoContainer, other.infoContainer, t)!,
      onInfoContainer: Color.lerp(onInfoContainer, other.onInfoContainer, t)!,
    );
  }
}

/// Tono visual de un indicador o alerta.
enum AppTone { neutral, info, success, warning, danger }

/// Colores resueltos de un [AppTone] para el tema actual.
@immutable
class AppToneColors {
  final Color foreground;
  final Color background;
  final Color border;

  const AppToneColors({
    required this.foreground,
    required this.background,
    required this.border,
  });
}

AppToneColors appToneColors(BuildContext context, AppTone tone) {
  final scheme = Theme.of(context).colorScheme;
  final semantic = AppSemanticColors.of(context);

  Color borderOf(Color color, Color background) =>
      Color.alphaBlend(color.withValues(alpha: 0.35), background);

  switch (tone) {
    case AppTone.neutral:
      final background = scheme.surfaceContainerHigh;
      return AppToneColors(
        foreground: scheme.onSurfaceVariant,
        background: background,
        border: scheme.outlineVariant,
      );
    case AppTone.info:
      return AppToneColors(
        foreground: semantic.info,
        background: semantic.infoContainer,
        border: borderOf(semantic.info, semantic.infoContainer),
      );
    case AppTone.success:
      return AppToneColors(
        foreground: semantic.success,
        background: semantic.successContainer,
        border: borderOf(semantic.success, semantic.successContainer),
      );
    case AppTone.warning:
      return AppToneColors(
        foreground: semantic.warning,
        background: semantic.warningContainer,
        border: borderOf(semantic.warning, semantic.warningContainer),
      );
    case AppTone.danger:
      return AppToneColors(
        foreground: scheme.error,
        background: scheme.errorContainer,
        border: borderOf(scheme.error, scheme.errorContainer),
      );
  }
}

/// Atajos de lectura del layout compartidos por las pantallas.
extension AppLayoutContext on BuildContext {
  Size get appSize => MediaQuery.sizeOf(this);
  double get appWidth => MediaQuery.sizeOf(this).width;
  bool get isMobileLayout => AppBreakpoints.isMobile(appWidth);
  bool get isTabletLayout => AppBreakpoints.isTablet(appWidth);
  bool get isDesktopLayout => AppBreakpoints.isDesktop(appWidth);
  AppSemanticColors get semanticColors => AppSemanticColors.of(this);

  /// Padding exterior coherente según el tamaño de ventana.
  EdgeInsets get pagePadding {
    if (isMobileLayout) {
      return const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg,
      );
    }
    if (isTabletLayout) {
      return const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.xl,
      );
    }
    return const EdgeInsets.fromLTRB(
      AppSpacing.xl,
      AppSpacing.lg,
      AppSpacing.xl,
      AppSpacing.xl,
    );
  }
}
