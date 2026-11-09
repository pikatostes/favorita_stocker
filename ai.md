# ai.md — Guía del proyecto para agentes IA

> Documento de consulta rápida. Léelo **antes** de tocar código.
> Última revisión: 2026-10-20.

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
| Dependencias | `supabase_flutter`, `intl`, `flutter_localizations` |
| Dev deps | `flutter_test`, `flutter_lints ^3.0.2` |
| Lint | `analysis_options.yaml` → `package:flutter_lints/flutter.yaml` (sin reglas propias) |
| Plataformas generadas | android, ios, linux, macos, web, windows (app de escritorio/móvil; sin lógica nativa propia) |

## 3. Cómo ejecutar y verificar

```powershell
flutter pub get
flutter analyze          # debe quedar limpio (flutter_lints)
flutter test             # toda la suite en test/
flutter run -d windows --dart-define-from-file=env.json
```

`env.json` (ignorado por Git) contiene `SUPABASE_URL` y
`SUPABASE_PUBLISHABLE_KEY`. En producción se pasan con `--dart-define` o
`--dart-define-from-file`. **Nunca** se usa la clave secreta en el cliente.

**Despliegue web:** `vercel.json` usa `scripts/vercel_build.sh`, que compila con
`--dart-define` a partir de las variables del proyecto. Los detalles (variables,
protección de despliegues y errores típicos) están en `DESPLIEGUE.md`. Si la
compilación no trae las claves, la app muestra una pantalla de aviso en vez de
quedarse en blanco.

**Regla de oro:** antes de dar por bueno un cambio, ejecuta `flutter analyze` y
`flutter test`. Si tocas lógica de dominio, **añade o ajusta tests** (ver §9).

La BD es **Supabase/Postgres** (online-first, sin caché local). Las migraciones
SQL viven en `supabase/migrations/` y se aplican desde el SQL Editor del
dashboard o con `supabase db push`. La app no crea tablas al arrancar.

## 4. Mapa de archivos

```
lib/
  main.dart              Arranque: Supabase.initialize, locale es y MaterialApp (temas claro/oscuro).
  theme.dart             Paleta de marca (AppColors), propuestas de tema (AppPalettes) y selector.
  models.dart            Dominio: formatMeasure, kGroupImages, CrateType, Product, SpecialDay, Forecast(Result).
  schedule.dart          Calendario/horario del bar (apertura, día de servicio, retención).
  shifts.dart            Turnos: Floor, ShiftStatus, JobRole, AppUser, Shift y ShiftGenerator.
  db.dart                Acceso a Supabase: singleton Db.i, vistas, RPC, Realtime y Auth.
  seed.dart              Catálogo inicial (initialProducts) en código (referencia histórica).
  prediction.dart        Predictor.forecast(): previsión en 2 pasos (base + temporada + margen).
  planner.dart           Planner.build(): monta cajas y reparte en viajes.
  product_entries.dart   buildProductEntries(): agrupa variantes para las listas de UI.
  screens/
    home.dart            Navegación adaptativa (barra inferior o menú lateral) + IndexedStack; Inicio (panel admin/empleado) y pestañas.
    registro.dart        "Lista": entrada de consumo de la noche + botón montar cajas.
    confirmar_lista.dart Pantalla intermedia: resumen del pedido y confirmación antes de guardar.
    turnos.dart          "Turnos": horario mensual, usuarios y puestos.
    plan.dart            Pantalla "Montar cajas" (compartida por Lista y Calendario).
    cuenta.dart          "Cuenta": datos del usuario y cambio de contraseña.
    forced_password.dart Bloqueo hasta cambiar la contraseña temporal.
    admin/
      admin.dart         "Admin": pestañas Calendario, Productos e Inventario.
      calendario.dart    "Calendario": mes, días trabajados, excepciones, detalle del día y previsión.
      productos.dart     "Productos": CRUD de catálogo (diálogo de alta/edición).
      inventario.dart    "Inventario": listado del catálogo con el stock disponible.
  widgets/
    category_tabs.dart   Pestañas por categoría (reutilizado en Lista y Productos).
  img/                   Imágenes de productos/grupos referenciadas por ruta (assets).
supabase/
  config.toml            Configuración de Supabase CLI (auth local sin confirmación).
  migrations/            Esquema, RLS/grants y RPC, en orden de timestamp.
  seed_catalog.sql       Catálogo inicial de ejemplo (productos y stock), idempotente.
  functions/admin-users/ Edge Function que crea/edita cuentas con la clave secreta.
scripts/
  migrate_sqlite.py      Exporta la SQLite antigua e importa en Supabase (export/push/verify).
  vercel_build.sh        Compila web pasando SUPABASE_URL y la clave publicable.
vercel.json              Build de Vercel → scripts/vercel_build.sh, salida build/web.
DESPLIEGUE.md            Puesta en marcha web (Vercel), variables y errores típicos.
test/                    Tests por módulo: models, planner, schedule, shifts, product_entries, etc.
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

### Turnos (`shifts.dart`)
- **`Floor`** = planta del local: `planta_baja`, `karaoke`, `terraza`.
- **`JobRole`** = puesto configurable: nombre, planta y nota fija (p. ej. evento
  privado en el karaoke).
- **`AppUser`** = nombre, un único `role`, `active` (baja lógica), `opener`
  (puede abrir el bar o su planta), `mustChangePassword` (contraseña temporal) y
  `workingDays` (días de la semana en que puede trabajar; vacío = cualquiera,
  solo se usa al generar el horario).
  `AppUser.isMaintenance` reconoce el puesto `manteni`/`mantenimiento` (sin
  distinguir mayúsculas ni acentos) para el aviso de lista en Inicio.
- **`Shift`** = turno de una noche: `date` (día de servicio `yyyy-MM-dd`),
  empleado, puesto (copia histórica de nombre y planta), `startMin`/`endMin`
  (minutos desde medianoche; si `endMin < startMin` termina al día siguiente),
  `breakMin`, `status` y `note`.
- `shiftDurationMinutes`, `breakMinutesFor` y `workedMinutesFor` centralizan la
  duración, el descanso y las horas efectivas.
- `ShiftGenerator.generateMonth(month, employees, specialDays)` reparte los
  turnos (ver §7).

## 6. Base de datos (`db.dart` + `supabase/`)

### 6.1 Acceso
- **Singleton `Db.i`**. Nunca instancies `Db`. La API pública imita la antigua
  capa SQLite para no tocar las pantallas.
- `Db.i.version` es un `ValueNotifier<int>` que se incrementa en **cada escritura**
  y en cada evento de **Realtime** (`_changed()`). Las pantallas se suscriben
  para recargar (§8).
- `Db.i.connectRealtime()` se llama al restaurar/iniciar sesión y abre un canal
  con `postgres_changes` sobre las tablas de la UI; `logout()` lo cierra.
- Errores de PostgREST se traducen a mensajes en español con `_friendly`
  (permisos, duplicados, clave foránea, etc.).

### 6.2 Esquema (Postgres, `supabase/migrations`)
Tablas en inglés singular: `category`, `box_type`, `product_group`,
`subcategory`, `product`, `night`, `consumption`, `special_day`, `job_role`,
`profiles`, `shift`.

- Los ids siguen siendo `bigint` (`generated by default as identity`) para no
  cambiar los modelos de Dart. `profiles` añade `auth_id uuid` → `auth.users`.
- **Vistas planas** (`security_invoker = true`) que reproducen las columnas que
  esperan los `fromRow`: `product_view`, `product_group_view`,
  `subcategory_view`, `user_view`.
- `product` guarda referencias: `box_id`, `group_id`, `subcategory_id`, `image`,
  `deleted_at` (borrado lógico).
- `consumption` = una fila por (noche, producto); `night` marca qué noches
  existen. UNIQUE(`night_id`,`product_id`), `quantity >= 0`.
- `job_role` es UNIQUE por `name` (más `name_key` normalizado) y guarda
  `floor` + `note`; `profiles` referencia `job_role_id` y guarda `opener`,
  `working_days` (`"5,6"`; vacío = cualquiera), `must_change_password`;
  `shift` referencia `profiles`/`job_role`, guarda copia de `role_name`,
  `floor` y `note`, y UNIQUE(`user_id`, `date`). Estados: `borrador`,
  `publicado`, `confirmado`.
- El alta de un usuario en `auth.users` crea su fila en `profiles` con el
  trigger `handle_new_user`.

### 6.3 Seguridad (RLS + grants)
- `anon` no tiene permisos; todo exige sesión `authenticated`. No basta con
  RLS: también hay `GRANT` explícitos (Postgres comprueba privilegios antes).
- Lectura: todo el equipo. Escritura directa de catálogo, puestos, perfiles,
  excepciones y turnos: solo `is_admin()`.
- `night` y `consumption` solo se escriben por RPC (`save_night`).
- `current_profile_id()` e `is_admin()` son `security definer` con
  `search_path = public`.
- Turnos: el empleado solo ve `publicado`/`confirmado`; el admin ve borradores.

### 6.4 RPC y Edge Function
- `save_product`, `set_group_image`: catálogo + upsert de categoría/grupo/
  subcategoría/caja en una transacción.
- `save_night(date, items)`: sustituye la lista de esa noche.
- `replace_month_shifts`, `publish_month`, `confirm_my_shift`: turnos.
- `update_own_profile`, `mark_password_changed`: perfil propio.
- `reset_sequences`, `purge_old_data`: solo `service_role` (importación y
  mantenimiento).
- **`admin-users`** (Edge Function): crear/editar/desactivar cuentas. Comprueba
  que quien llama es admin activo y usa la clave secreta, que nunca sale del
  servidor. Contraseña temporal por defecto: `favorita`.

### 6.5 Autenticación
- `authenticate()` = `signInWithPassword` + perfil por `auth_id`; si el perfil
  no existe o está inactivo, cierra la sesión.
- `registerUser()` = `signUp`; requiere que la confirmación por email esté
  desactivada (los correos `@favorita.local` no reciben nada).
- `AppUser.mustChangePassword` bloquea la app con `ForcedPasswordScreen` hasta
  llamar a `setPassword()` + `mark_password_changed`.
- `changePassword()` desde Cuenta reautentica con la contraseña actual.

### 6.6 Importación desde SQLite
`scripts/migrate_sqlite.py`:
1. `export --db privado/stock_bar.db` → JSON (sin red).
2. `push` con `SUPABASE_URL` + `SUPABASE_SECRET_KEY` en el entorno: crea las
   cuentas de Auth, actualiza `profiles`, inserta el resto y reajusta secuencias.
3. `verify` → conteos por tabla.

La clave secreta **nunca** se escribe en el repo ni se pasa por el chat.

Si no hay base antigua, `supabase/seed_catalog.sql` carga el catálogo de ejemplo
(35 productos con stock) desde el SQL Editor. Es idempotente y no pisa productos
existentes.

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

En la UI, `Predictor.forecast` se usa en el panel de Inicio del administrador y
en el detalle del día del Calendario: al seleccionar un día abierto, desde hoy
en adelante y sin lista guardada, se muestra la previsión y el botón para
montar cajas según ella.

### Montaje de cajas (`planner.dart`, `Planner.build`)
- 0) **Cajas dedicadas** (un solo producto): las pedidas en `fullBoxes` y, si
  `preferFull`, las que salen de dividir por `unitsPerBox`.
- 1) El resto se **mezcla** solo entre productos con igual `size|height|width|format|unitsPerBox`,
  mínimo de cajas posible.
- 2) Cada tipo de caja ocupa `1/N` del carro (N = `tripCapacity` de ese tipo). La
  capacidad del carro = **mcm** de esos N; el coste de una caja = `carro / N`.
  Reparto en viajes por **first-fit decreasing**.

### Turnos (`shifts.dart`, `ShiftGenerator.generateMonth`)
- Solo se generan **viernes y sábado** (`Schedule.openWeekdays`). Se respetan
  los cierres de `SpecialDay` (`open=false`); las aperturas extra no se generan.
- Tres tipos de turno: apertura **16:00–21:00** (5 h), segundo **21:00–04:00**
  (7 h) y completo **16:00–04:00** (12 h) cuando hace falta cubrir ambos
  tramos. Cada empleado activo hace un turno por noche; no hay turno partido.
- **Descanso** solo si se entra antes de las 21:00: >8 h → 40 min; >6 h →
  25 min. Se guarda en `shift.break_min` y no se cuenta como trabajado.
- **Terraza**: los **viernes abre a las 21:00**, así que todo su personal
  entra al segundo turno (no se genera turno a las 16:00); los **sábados abre
  a las 16:00** con el reparto normal. En ambos casos necesita **al menos dos
  personas desde la hora de apertura**. Si faltan empleados, se programa a
  todos los disponibles y la terraza puede quedar incompleta.
- **Mínimos de cobertura**: cada planta necesita al menos una persona en la
  apertura y otra en el segundo turno. El generador usa turnos completos
  cuando no hay suficientes personas para cubrir ambos tramos por separado.
- **Equidad por planta**: dentro de cada `Floor` se ordenan los empleados por
  horas acumuladas del mes y los turnos más largos (completo > segundo >
  apertura) van a quien lleva menos. Si una planta tiene una sola persona, esa
  persona cubre la noche completa (16:00–04:00, o 21:00–04:00 en la terraza de
  los viernes) para no dejar la planta vacía. La equidad global no se fuerza
  entre plantas con distinto número de personas.
- **Disponibilidad**: un empleado solo entra en un día si `workingDays` está
  vacío o contiene el día de la semana de esa fecha.
- **Apertura solo con `opener`**: los turnos que empiezan a las 16:00 (apertura
  y completo) solo se asignan a empleados con `opener = true`. Los no-openers
  van siempre al segundo turno. Si una planta no tiene ningún opener disponible
  esa noche, **no se programa** (el hueco queda visible en el calendario); en la
  terraza de los viernes, que abre a las 21:00, basta con que haya un opener
  entre el personal programado.
- `ShiftGenerator` usa el **día de servicio** (`Schedule.fmt`) y recorre el mes
  por componentes, no con `Duration(days: 1)`, para no perder el último día en
  los cambios de hora oficial.
- Regenerar un mes **sustituye** todos sus turnos (incluidos cambios manuales);
  la UI avisa. Publicar pasa los borradores a `publicado`; confirmar es por turno.

### Retención
`purgeOld()` (llamado en `main`) borra consumo/noches/excepciones/turnos
anteriores a hoy − 2 años (`Schedule.retentionYears`).

### Agrupación para la UI (`product_entries.dart`)
- Un grupo se despliega **solo si tiene ≥2 productos**; si no, va suelto.
- Etiqueta de variante = subcategoría o, si falta, su nombre.
- Orden: primero grupos de variantes (orden original), después sueltos.

## 8. UI y patrones (`screens/`, `widgets/`)

- **Navegación**: `HomeScreen` con `IndexedStack` y una navegación adaptativa
  (`homeNavigationMode`): en **web** siempre es un **menú lateral a la izquierda**
  (`NavigationRail`), compacto en ventanas estrechas y extendido a partir de
  1080 px; en el resto de plataformas se usa `NavigationBar` en móvil y menú
  lateral cuando el ancho supera 840 px. Inicio es la primera pestaña; Lista,
  Turnos y Cuenta son comunes. Admin agrupa Calendario, Productos e Inventario
  y solo aparece para `UserRole.admin`.
  La previsión está integrada en el detalle del día del Calendario: se muestra
  en días abiertos sin lista guardada y desde hoy en adelante. También se
  resume en el panel de Inicio del administrador.
- **Inicio**: panel contextual por rol. El administrador ve turnos y personal
  de la noche, estado del mes, previsión y avisos, con acciones para
  generar/publicar. El empleado ve su próximo turno, sus horas, el equipo de la
  noche y avisos; los turnos en borrador no se muestran. Quien tiene el puesto
  de mantenimiento (`AppUser.isMaintenance`) ve además, destacada al principio,
  una tarjeta con la última lista guardada (`Db.latestNightDate()`): indica si
  hay lista y, si la hay, resume productos/botellines y abre `PlanScreen` con
  los sueltos y las cajas completas reconstruidos. Es el sustituto provisional
  del sistema de notificaciones.
- **Recarga reactiva**: cada pantalla hace en `initState`
  `Db.i.version.addListener(_reload)` y lo quita en `dispose`. `_reload` vuelve a
  lanzar el `Future` y hace `setState`. **Mantén este patrón.**
- **Carga de datos**: siempre `FutureBuilder` con estados loading/error/vacío.
- **`CategoryTabs`**: genera las pestañas a partir de las categorías de los productos;
  recrea el `TabController` solo si cambian las categorías (evita la aserción de tabs).
- **`TurnosScreen`** (`screens/turnos.dart`): `TabBar` con Horario, Usuarios y
  Puestos (este último solo para administradores). Horario es un calendario
  mensual: los días con turnos se rellenan, los días que abren sin turnos se
  marcan con borde y las excepciones con color. Al tocar un día se muestran sus
  turnos agrupados en pestañas por planta, con una **línea temporal horizontal**
  de 16:00 a 04:00: cada fila es un horario exacto y reúne a todas las personas
  que lo comparten. La barra rotula solo su entrada y su salida (sin eje horario
  completo ni columna lateral) y lleva los avatares dentro; si no caben, pasan a
  otra línea y la fila crece en vertical. El admin toca un avatar para editarlo y
  lo mantiene pulsado para borrarlo (con confirmación); el empleado toca su
  turno publicado para **confirmarlo** y no puede editar los de nadie. El admin
  puede generar/publicar el mes. Los formularios de empleado y puesto son
  diálogos con sus propios controllers (mismo patrón que Productos).
- **Formulario de producto** (`_ProductDialog`): categoría, grupo, subcategoría y tipo
  de caja son **desplegables estrictos** (solo valores existentes en BD). Los números
  describen la caja seleccionada, **compartida** por todos los productos de ese tipo.
  El diálogo es dueño de sus `TextEditingController` y los destruye en `dispose`
  (no destruirlos antes de que el diálogo se desmonte: provocaba `_dependents.isEmpty`).
- **Confirmación de la lista** (`screens/confirmar_lista.dart`): al pulsar
  "Guardar y montar cajas" en Lista se abre una pantalla intermedia con el
  resumen del pedido (por categoría, cajas/sueltos y totales). Solo si se
  confirma se guarda la noche y se navega a `PlanScreen`; volver no escribe nada.
  Tras guardar, el usuario recibe un SnackBar de éxito salvo que sea de
  mantenimiento: ese puesto sigue el estado desde la tarjeta de Inicio.
- Imágenes por ruta/URI (`Image.asset` con `errorBuilder` → placeholder).
- Textos de UI, `NumberFormat`/`DateFormat` con locale `'es'` (`intl`, `initializeDateFormatting('es')`).

## 9. Tests (`test/`)

Un archivo por módulo, tests de **comportamiento** (sin mocks de UI salvo widgets):

| Archivo | Cubre |
|---|---|
| `models_test.dart` | Defaults, validación, `fromRow`, `boxInfo`, `Forecast.boxes`, `SpecialDay`. |
| `inventario_test.dart` | Stock en cajas completas + unidades sueltas, agrupación de variantes y `SpecialDay` boolean/entero. |
| `planner_test.dart` | Cajas dedicadas/mezcladas, tipos distintos, reparto en viajes. |
| `schedule_test.dart` | Formato, `serviceDay`, apertura y excepciones, `nextOpen`, retención. |
| `shifts_test.dart` | Duración, descansos, reparto por planta, equidad, cierres, notas y plantas. |
| `product_entries_test.dart` | Agrupación, etiquetas, orden, imágenes. |
| `category_tabs_test.dart` | Widget: añadir/quitar categorías y alternar pantalla sin excepciones. |
| `admin_tabs_test.dart` | Pestañas internas de Admin (Calendario, Productos e Inventario). |
| `confirmar_lista_test.dart` | Widget: resumen del pedido y resultado de confirmar/volver. |
| `home_tabs_test.dart` | Pestañas visibles de Inicio según el rol. |
| `turnos_tabs_test.dart` | Pestañas internas de Turnos y acceso a Puestos. |

Convención: helpers `_p(...)`/`_product(...)` para construir objetos de prueba.
Al cambiar dominio o esquema, actualiza/crea el test correspondiente. La capa de
datos ya no se testea con SQLite: los tests cubren lógica pura y widgets; las
migraciones se validan con `pglast`/el SQL Editor y el script de importación.

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

1. ¿Cambié el esquema? → nueva migración en `supabase/migrations/` con timestamp
   posterior, aplicar en local/remoto y ajustar vistas/RPC/RLS.
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
- **Migraciones**: cada cambio de esquema es un archivo nuevo en
  `supabase/migrations/`; no edites uno ya aplicado. Mantén las vistas y los
  `fromRow` sincronizados.
- **RLS + grants**: añadir una política no basta; sin `grant` al rol
  `authenticated` PostgREST sigue devolviendo permiso denegado.
- **Clave secreta**: `service_role`/`sb_secret_…` solo en la Edge Function o en
  el script de importación (variable de entorno). Nunca en Flutter ni en Git.
- **Web/Vercel**: `String.fromEnvironment` se resuelve al compilar. Sin
  `--dart-define` la app no ve las claves (muestra la pantalla «Falta configurar
  Supabase»); el build de Vercel está en `vercel.json` + `scripts/vercel_build.sh`.
- **Controllers en diálogos**: crea y destruye junto al diálogo (ver §8).
- **Assets**: las imágenes se referencian por ruta `lib/img/...` y están declaradas
  en `pubspec.yaml`; un archivo inexistente cae al placeholder, no rompe.
- **Turnos y DST**: no recorras días con `Duration(days: 1)`; en el cambio de
  hora oficial se pierde el último día. Usa componentes (`DateTime(y, m, day)`).
- **Regenerar un mes** borra los turnos de ese mes, también los publicados o
  confirmados. Si en el futuro hay que conservarlos, cambia
  `replaceMonthShifts` y añade tests.
- **Equidad de turnos** es por planta: una planta con una sola persona trabaja
  12 h cada noche. Para repartir mejor, añade más personal a esa planta.
- **Mínimo de terraza**: con pocos openers no se pueden cubrir las dos personas
  desde la apertura; el generador programa a todos los disponibles y el hueco
  queda visible, pero no inventa personal.
- **Confirmación multidispositivo**: el estado `confirmado` ya se guarda en
  Supabase y se sincroniza por Realtime. Requiere que la publicación
  `supabase_realtime` incluya la tabla `shift` (lo hace la migración 0002).
