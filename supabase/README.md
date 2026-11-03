# Puesta en marcha de Supabase

Guía para dejar el proyecto remoto listo. Se hace **una sola vez** (y luego una
vez por cada migración nueva).

## 1. Desactivar la confirmación por email

Los usuarios son internos (`@favorita.local`) y no reciben correo.

Dashboard → **Authentication** → **Sign In / Providers** → **Email**:

- **Confirm email**: desactivado.
- **Allow new users to sign up**: activado (si quieres permitir el registro
  desde la pantalla de la app).

Sin esto, `signUp` no devuelve sesión y los usuarios creados no pueden entrar.

## 2. Ejecutar las migraciones

Dashboard → **SQL Editor** → **New query**. Pega y ejecuta, **en este orden**:

1. `supabase/migrations/20261103000100_schema.sql`
2. `supabase/migrations/20261103000200_security.sql`
3. `supabase/migrations/20261103000300_rpc.sql`

Cada archivo debe terminar en `Success`. Si algo falla, corrige y vuelve a
ejecutarlo: son idempotentes en su mayor parte (`if not exists`,
`create or replace`, `drop policy if exists`).

Comprobación rápida en el SQL Editor:

```sql
select table_name
from information_schema.tables
where table_schema = 'public'
order by table_name;
```

Deben aparecer `category`, `box_type`, `product_group`, `subcategory`,
`product`, `night`, `consumption`, `special_day`, `job_role`, `profiles` y
`shift` (además de las cuatro vistas `*_view`).

## 3. Desplegar la Edge Function `admin-users`

Solo ella puede crear/editar cuentas, porque necesita la clave secreta.

**Opción A — Dashboard:** **Edge Functions** → **Deploy a new function** →
nombre `admin-users` → pega el contenido de
`supabase/functions/admin-users/index.ts` → **Deploy**.

**Opción B — CLI:**

```powershell
supabase functions deploy admin-users
```

La función usa `SUPABASE_URL`, `SUPABASE_ANON_KEY`/`SUPABASE_PUBLISHABLE_KEY` y
`SUPABASE_SERVICE_ROLE_KEY`/`SUPABASE_SECRET_KEYS`, que Supabase inyecta sola.
**No** hay que configurar secretos a mano.

## 4. Crear el primer administrador

El trigger `handle_new_user` crea el perfil, pero entra como `employee`.

**Opción A (recomendada):** abre la app, pulsa **Registrarme** y crea tu cuenta.
Después, en el SQL Editor:

```sql
update public.profiles
   set role = 'admin', must_change_password = false
 where lower(email) = lower('tu@email.com');
```

**Opción B:** Dashboard → **Authentication** → **Users** → **Add user** (marca
“Auto Confirm User”), y luego el mismo `update`.

Cierra y vuelve a abrir sesión en la app para que el rol se refresque.

## 5. Arrancar la app

`env.json` (ignorado por Git) debe existir en la raíz:

```json
{
  "SUPABASE_URL": "https://<ref>.supabase.co",
  "SUPABASE_PUBLISHABLE_KEY": "sb_publishable_..."
}
```

```powershell
flutter pub get
flutter run -d windows --dart-define-from-file=env.json
```

La clave **publicable** puede viajar al cliente. La clave **secreta**
(`sb_secret_...` / `service_role`) no se usa nunca en Flutter ni se sube al
repo.

## 6. Importar la base antigua (opcional)

Con la app antigua cerrada y una copia de `stock_bar.db`:

```powershell
python scripts/migrate_sqlite.py export --db privado/stock_bar.db

$env:SUPABASE_URL = "https://<ref>.supabase.co"
$env:SUPABASE_SECRET_KEY = "sb_secret_..."   # solo en esta terminal
python scripts/migrate_sqlite.py push

Remove-Item Env:\SUPABASE_SECRET_KEY
python scripts/migrate_sqlite.py verify
```

`push` crea las cuentas de Auth con contraseña temporal **`favorita`**, marca
`must_change_password` y conserva ids, catálogo, consumo y turnos. Al entrar por
primera vez, la app obliga a elegir una contraseña nueva.

## Problemas frecuentes

| Síntoma | Causa |
|---|---|
| `PGRST205: Could not find the table ...` | Las migraciones no se han ejecutado. |
| `new row violates row-level security policy` | Falta la política **o** el `grant` a `authenticated`. |
| `permission denied for table ...` | Falta el `grant` (la RLS por sí sola no basta). |
| `Invalid login credentials` | Usuario inexistente o contraseña distinta de `favorita`. |
| `Email not confirmed` | Vuelve al paso 1 o crea la cuenta con “Auto Confirm”. |
| La app arranca y se queda en el login | Revisa `env.json` y que `--dart-define-from-file` apunte a él. |
| Los cambios no llegan a otros dispositivos | Comprueba que la tabla está en la publicación `supabase_realtime` (migración 0002). |
