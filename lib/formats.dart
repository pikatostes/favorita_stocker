import 'package:intl/intl.dart';

/// Pone en mayúscula la primera letra.
///
/// El locale español devuelve los días y meses en minúscula, así que se usa
/// al principio de una frase o de una etiqueta.
String capitalize(String value) =>
    value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);

/// Fecha larga en español: «Viernes 8 de noviembre».
String formatLongDate(DateTime date) =>
    capitalize(DateFormat('EEEE d MMMM', 'es').format(date));

/// Fecha corta en español: «Vie 8 nov».
String formatShortDate(DateTime date) =>
    capitalize(DateFormat('EEE d MMM', 'es').format(date));

/// Día de la semana corto: «Vie». Para cabeceras compactas en dos líneas.
String formatWeekdayShort(DateTime date) =>
    capitalize(DateFormat('EEE', 'es').format(date));

/// Día y mes cortos: «8 nov». Complementa a [formatWeekdayShort].
String formatDayMonth(DateTime date) => DateFormat('d MMM', 'es').format(date);

/// Fecha larga a partir de una fecha ISO (`yyyy-MM-dd`).
String formatLongDateIso(String date) => formatLongDate(DateTime.parse(date));

/// Fecha corta a partir de una fecha ISO (`yyyy-MM-dd`).
String formatShortDateIso(String date) => formatShortDate(DateTime.parse(date));

/// Mes y año en español: «Noviembre 2026».
String formatMonthLabel(DateTime date) =>
    capitalize(DateFormat('MMMM yyyy', 'es').format(date));
