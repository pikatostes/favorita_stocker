# ai.md — Guía del proyecto para agentes IA

> Documento de consulta rápida. Léelo **antes** de tocar código.
> Última revisión: 2026-10-16.

---

## 1. Qué es

`stock_bar` (repo `favorita_stocker`) es una app **Flutter** para un bar:
registrar el consumo de cada noche, **prever** qué reponer y **montar cajas/viajes**.

- **Todo el código y los comentarios están en español.** Respeta ese idioma en
  comentarios, textos de UI, nombres de dominio y mensajes de error.
- Es de un solo desarrollador (repo personal). No hay CI ni convenciones
  corporativas: la coherencia con lo que ya existe manda.
- `README.md` es el texto por defecto de Flutter, **no** documenta nada. Este es
  el documento de referencia real.

## 2. Stack y entorno

| Cosa | Valor |
|---|---|
| Framework | Flutter 3.35.7 (stable), Dart 3.9.2 |
| SDK | `>=3.0.0 <4.0.0` |
| Versión app | 0.2.0 (`pubspec.yaml`) |
| Dependencias | `sqflite`, `path`, `intl` |
| Dev deps | `flutter_test`, `flutter_lints ^3.0.2`, `sqflite_common_ffi` |
| Lint | `analysis_options.yaml` → `package:flutter_lints/flutter.yaml` (sin reglas propias) |
| Plataformas generadas | android, ios, linux, macos, web, windows (app de escritorio/móvil; sin lógica nativa propia) |

## 3. Cómo ejecutar y verificar

```powershell
flutter pub get
flutter analyze          # debe quedar limpio (flutter_lints)
flutter test             # toda la suite en test/
flutter run -d windows   # o -d chrome / dispositivo
```

**Regla de oro:** antes de dar por bueno un cambio, ejecuta `flutter analyze` y
`flutter test`. Si tocas lógica de dominio, **añade o ajusta tests** (ver §9).

La BD en runtime es SQLite local (`stock_bar.db`) vía `sqflite`; en tests se usa
`sqflite_common_ffi` con BD temporales reales.

## 4. Mapa de archivos

```
lib/
  main.dart              Arranque: locale es, seed, purgeOld, MaterialApp (tema ámbar M3, claro/oscuro).
  models.dart            Dominio: formatMeasure, kGroupImages, CrateType, Product, SpecialDay, Forecast(Result).
  schedule.dart          Calendario/horario del bar (apertura, día de servicio, retención).
  db.dart                Acceso a SQLite. Singleton Db.i, esquema + migraciones, CRUD. (archivo grande, ~890 líneas)
  seed.dart              Catálogo inicial (initialProducts) en código.
  seed_runner.dart       initializeSeedData() -> Db.seedCatalog(initialProducts).
  prediction.dart        Predictor.forecast(): previsión en 2 pasos (base + temporada + margen).
  planner.dart           Planner.build(): monta cajas y reparte en viajes.
  product_entries.dart   buildProductEntries(): agrupa variantes para las listas de UI.
  screens/
    home.dart            NavigationBar con 4 pestañas (IndexedStack).
    registro.dart        "Lista": entrada de consumo de la noche + botón montar cajas.
    prevision.dart       "Previsión": previsión por fecha + montar cajas.
    calendario.dart      "Calendario": mes, días trabajados, excepciones, detalle del día.
    productos.dart       "Productos": CRUD de catálogo (diálogo de alta/edición).
    plan.dart            Pantalla "Montar cajas" (compartida por las 3 anteriores).
  widgets/
    category_tabs.dart   Pestañas por categoría (reutilizado en Lista y Productos).
  img/                   Imágenes de productos/grupos referenciadas por ruta (assets).
test/                    Tests por módulo: db, models, planner, schedule, product_entries, category_tabs.
```

## 5. Modelo de dominio (`models.dart`)

- **`CrateType`** = tipo de caja: `name` (en BD, columna `type`), `units` (uds/caja),
  `size`, `height`, `width`, `format`, `trip` (cajas de este tipo por viaje).
  Varios productos **comparten** el mismo tipo de caja.
- **`Product`** = producto del catálogo. Campos de lectura `category`, `groupName`,
  `subcategory` se rellenan desde el JOIN. Delega los atributos físicos en `box`
  (atajos: `unitsPerBox`, `size`, `height`, `width`, `format`, `crateName`, `tripCapacity`).
  - `groupName` es **obligatorio** (la categoría se deriva del grupo).
  - `deleted` es **borrado lógico** (`deleted_at`).
  - `validationError` centraliza las validaciones; úsalo antes de guardar.
  - `Product.fromRow(map)` construye desde la fila del JOIN de `Db.products()`.
- **`SpecialDay`** = excepción de calendario: `date` (`yyyy-MM-dd`), `open` (bool), `note`.
- **`Forecast`** = (producto, unidades previstas); `boxes` = techo de `units/unitsPerBox`.
- **`ForecastResult`** = items + `recentNights` + `seasonalYears` (metadatos para la UI).
- `formatMeasure(double)`: quita decimales innecesarios (`1.0 -> "1"`).
- `kGroupImages`: imágenes por nombre de grupo; si no está o el archivo falta, la UI
  muestra placeholder.

## 6. Base de datos (`db.dart`)

### 6.1 Acceso
- **Singleton `Db.i`**. Nunca instancies `Db`.
- `Db.i.version` es un `ValueNotifier<int>` que se incrementa en **cada escritura**
  (`_changed()`). Las pantallas se suscriben para recargar (§8).
- `schemaVersion = 11`. Abrir con `Db.openAt(path)` (expuesto `@visibleForTesting`).

### 6.2 Esquema normalizado (v8+), tablas en inglés singular
`category`, `box`, `product_group`, `subcategory`, `product`, `night`,
`consumption`, `special_day`, `app_metadata`.

- `product` guarda **referencias**: `box_id`, `group_id`, `subcategory_id`, `image`, `deleted_at`.
- `product_group` es UNIQUE(`category_id`, `name`) y guarda `image` (imagen del grupo).
- `consumption` = una fila por (noche, producto); `night` marca qué noches existen.
  UNIQUE(`night_id`,`product_id`), `quantity >= 0`.
- `PRAGMA foreign_keys = ON` en `onConfigure`.
- Helpers internos `_ensureCategory/_ensureGroup/_ensureSubcategory/_upsertBox`
  resuelven o crean entidades por nombre. `_upsertBox` es **UPSERT por `type`**
  (mismo nombre de caja = mismos atributos; los últimos datos pisan a los anteriores).

### 6.3 Migraciones (histórico)
`onUpgrade` aplica por versiones: v2 special_days, v3–v5 columnas desnormalizadas,
v6 app_metadata, v7 product_groups+image, v8 normalización, v9 reparación de grupos
de variantes históricos, v10 reagrupación de cervezas por marca, v11 imágenes de grupo.

**Para cambiar el esquema:** sube `schemaVersion`, añade el bloque `if (oldV < N) ...`
en `_onUpgrade`, y **añade un test de migración** en `test/db_test.dart`.
Nunca edites `_createV8` sin actualizar también las migraciones (los tests crean v7
y comprueban que sube al esquema actual).

### 6.4 API pública habitual
`products({includeDeleted})`, `categories()`, `boxTypes()`, `productGroups()`,
`subcategories()`, `addProduct/updateProduct/deleteProduct`, `productGroupImage`,
`setProductGroupImage`, `saveNight(date, Map<int,int>)`, `nights([since])`,
`specialDays/setSpecialDay/deleteSpecialDay`, `seedCatalog`, `purgeOld`.
`_productSelect` es el JOIN canónico producto↔grupo↔categoría↔subcategoría↔caja.

## 7. Reglas de negocio

### Calendario (`schedule.dart`)
- Abre **viernes y sábado** (`openWeekdays`); `openHour=16`, cierra a las 04:00.
- `serviceDay(now)`: la noche empieza a las 16:00 → a las 03:00 sigue siendo "ayer".
- `isOpen(d, special)`: las excepciones (`SpecialDay`) mandan sobre el calendario.
- `nextOpen(from, special)`, `fmt` (`yyyy-MM-dd`), `retentionLimit` (hoy − 2 años).
- `peakHour=21` (de 21:00 a 04:00 hay más gente y personal).

### Previsión (`prediction.dart`, `Predictor.forecast(target)`)
1. **Base**: media ponderada de las últimas 8 noches comparables (`maxNights=8`,
   decaimiento `decay=0.85`; si el objetivo es viernes/sábado, solo esas; si no hay, cualquiera).
2. **Temporada**: factor que compara la época del objetivo con la época de las noches
   base en años anteriores (±21 días, mínimo 2 noches por ventana, ratio acotado a [0.5, 2.0]).
3. **Margen** de seguridad `+10%`, redondeo hacia arriba.
Devuelve items ordenados de mayor a menor. Ampliaciones futuras previstas:
eventos, meteorología, stock sobrante.

### Montaje de cajas (`planner.dart`, `Planner.build`)
- 0) **Cajas dedicadas** (un solo producto): las pedidas en `fullBoxes` y, si
  `preferFull`, las que salen de dividir por `unitsPerBox`.
- 1) El resto se **mezcla** solo entre productos con igual `size|height|width|format|unitsPerBox`,
  mínimo de cajas posible.
- 2) Cada tipo de caja ocupa `1/N` del carro (N = `tripCapacity` de ese tipo). La
  capacidad del carro = **mcm** de esos N; el coste de una caja = `carro / N`.
  Reparto en viajes por **first-fit decreasing**.

### Retención
`purgeOld()` (llamado en `main`) borra consumo/noches/excepciones anteriores a
hoy − 2 años (`Schedule.retentionYears`).

### Agrupación para la UI (`product_entries.dart`)
- Un grupo se despliega **solo si tiene ≥2 productos**; si no, va suelto.
- Etiqueta de variante = subcategoría o, si falta, su nombre.
- Orden: primero grupos de variantes (orden original), después sueltos.

## 8. UI y patrones (`screens/`, `widgets/`)

- **Navegación**: `HomeScreen` con `NavigationBar` + `IndexedStack` (4 pestañas:
  Lista, Previsión, Calendario, Productos).
- **Recarga reactiva**: cada pantalla hace en `initState`
  `Db.i.version.addListener(_reload)` y lo quita en `dispose`. `_reload` vuelve a
  lanzar el `Future` y hace `setState`. **Mantén este patrón.**
- **Carga de datos**: siempre `FutureBuilder` con estados loading/error/vacío.
- **`CategoryTabs`**: genera las pestañas a partir de las categorías de los productos;
  recrea el `TabController` solo si cambian las categorías (evita la aserción de tabs).
- **Formulario de producto** (`_ProductDialog`): categoría, grupo, subcategoría y tipo
  de caja son **desplegables estrictos** (solo valores existentes en BD). Los números
  describen la caja seleccionada, **compartida** por todos los productos de ese tipo.
  El diálogo es dueño de sus `TextEditingController` y los destruye en `dispose`
  (no destruirlos antes de que el diálogo se desmonte: provocaba `_dependents.isEmpty`).
- Imágenes por ruta/URI (`Image.asset` con `errorBuilder` → placeholder).
- Textos de UI, `NumberFormat`/`DateFormat` con locale `'es'` (`intl`, `initializeDateFormatting('es')`).

## 9. Tests (`test/`)

Un archivo por módulo, tests de **comportamiento** (sin mocks de UI salvo widgets):

| Archivo | Cubre |
|---|---|
| `db_test.dart` | Creación esquema, migraciones v7→actual, reparaciones v9/v10/v11. Usa `sqflite_common_ffi` + BD temporal. |
| `models_test.dart` | Defaults, validación, `fromRow`, `boxInfo`, `Forecast.boxes`, `SpecialDay`. |
| `planner_test.dart` | Cajas dedicadas/mezcladas, tipos distintos, reparto en viajes. |
| `schedule_test.dart` | Formato, `serviceDay`, apertura y excepciones, `nextOpen`, retención. |
| `product_entries_test.dart` | Agrupación, etiquetas, orden, imágenes. |
| `category_tabs_test.dart` | Widget: añadir/quitar categorías y alternar pantalla sin excepciones. |

Convención: helpers `_p(...)`/`_product(...)` para construir objetos de prueba.
Al cambiar dominio o esquema, actualiza/crea el test correspondiente.

## 10. Convenciones de código

- Español en todo lo visible (comentarios `///`, UI, mensajes).
- Estilo Flutter estándar, `flutter_lints` limpio. Preferencia por expresiones y
  colecciones (`for` en literales, `Map`/`Set` funcionales).
- `dart format` con 80 columnas de facto (el código existente las respeta).
- Modelos inmutables (`final`), `copyWith` donde hace falta (`CrateType`).
- Comentarios `///` con `[referencias]` a símbolos; explican **por qué**, no qué.
- No introduces estado global fuera de `Db.i.version`; no añadas `ChangeNotifier`
  por pantalla (regla: los datos cambian por escritura en BD).

## 11. Checklist antes de terminar un cambio

1. ¿Cambié el esquema? → subir `schemaVersion`, migración en `_onUpgrade`, test de migración.
2. ¿Cambié dominio/schedule/planner/predicción? → actualizar/añadir test.
3. ¿Nueva escritura en BD? → llamar a `_changed()` (ya lo hacen los métodos de `Db`).
4. ¿Cambié UI con datos de BD? → respetar el patrón `version.addListener(_reload)`.
5. `flutter analyze` y `flutter test` en verde.
6. Textos/comentarios en español, coherentes con el resto.

## 12. Trampas conocidas (gotchas)

- **`groupName` obligatorio**: sin grupo, `validationError` no es null y el guardado falla.
- **Cajas compartidas por `type`**: editar los números de un producto con un tipo de
  caja existente cambia los atributos para **todos** los productos de ese tipo.
- **Borrado lógico**: `deleteProduct` no borra datos; el histórico se conserva y
  `Calendario` lista productos con `includeDeleted: true` para mostrarlo.
- **`serviceDay`**: no uses `DateTime.now().date` para la "noche"; antes de las 16:00
  pertenece al día anterior.
- **Migraciones**: los tests crean una BD v7 real; cualquier cambio de esquema debe
  seguir pasando esas migraciones.
- **Controllers en diálogos**: crea y destruye junto al diálogo (ver §8).
- **Assets**: las imágenes se referencian por ruta `lib/img/...` y están declaradas
  en `pubspec.yaml`; un archivo inexistente cae al placeholder, no rompe.
