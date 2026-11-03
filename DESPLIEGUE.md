# Despliegue web (Vercel)

La app es Flutter Web + Supabase. La única complicación es que las claves de
Supabase se inyectan **en tiempo de compilación** con `--dart-define`: Vercel no
lee `env.json` (está ignorado por Git) y `String.fromEnvironment` no ve las
variables del sistema.

## 1. Variables de entorno en Vercel

**Settings → Environment Variables** (marca Production, Preview y Development):

| Nombre | Valor |
|---|---|
| `SUPABASE_URL` | `https://<ref>.supabase.co` |
| `SUPABASE_PUBLISHABLE_KEY` | `sb_publishable_...` |

Solo la clave **publicable**. La clave secreta (`service_role` / `sb_secret_...`)
no se usa nunca en el cliente.

## 2. Configuración del build

`vercel.json` (en la raíz) ya apunta al script:

```json
{
  "buildCommand": "bash scripts/vercel_build.sh",
  "outputDirectory": "build/web"
}
```

`scripts/vercel_build.sh` comprueba que las variables existen y compila con
`--dart-define`. Usa `flutter` del `PATH` o, si el paso de instalación clona el
SDK en `./flutter`, `flutter/bin/flutter`.

El **Install Command** sigue siendo el del proyecto. Si algún día hay que
recrearlo, el habitual para Flutter en Vercel es:

```bash
if cd flutter; then git pull && cd ..; else git clone https://github.com/flutter/flutter.git; fi \
  && flutter/bin/flutter doctor && flutter/bin/flutter clean \
  && flutter/bin/flutter config --enable-web
```

`.gitattributes` fuerza LF en `*.sh`; un script con CRLF falla en Linux.

## 3. Protección de despliegues (el aviso de CORS del manifest)

Si la URL es de tipo `*-git-rama-proyecto.vercel.app` y al abrirla pide login de
Vercel, el despliegue tiene **Deployment Protection**. El navegador carga la app
(la navegación sí lleva cookie), pero el `<link rel="manifest">` se pide sin
credenciales, Vercel lo redirige al SSO y el navegador lo bloquea con:

```
Access to manifest ... has been blocked by CORS policy
```

No es un fallo de la app y no afecta a su funcionamiento. Para quitarlo:

- **Settings → Deployment Protection → Vercel Authentication**: desactivar, o
- usar el dominio de producción (no protegido), o
- añadir un *Protection Bypass* y usarlo solo para pruebas.

## 4. Comprobación

```powershell
flutter run -d chrome --dart-define-from-file=env.json   # local
# o, replicando Vercel:
$env:SUPABASE_URL = "https://<ref>.supabase.co"
$env:SUPABASE_PUBLISHABLE_KEY = "sb_publishable_..."
bash scripts/vercel_build.sh
```

## Problemas frecuentes

| Síntoma | Causa |
|---|---|
| Página en blanco y `Uncaught Error` en consola | La compilación no trae las claves: faltan las variables en Vercel o el Build Command no usa `scripts/vercel_build.sh`. Ahora la app muestra una pantalla «Falta configurar Supabase» en ese caso. |
| `Access to manifest ... blocked by CORS` | Deployment Protection de Vercel (paso 3). |
| `Faltan SUPABASE_URL y/o SUPABASE_PUBLISHABLE_KEY` en el log del build | Las variables no están definidas para ese entorno (Production/Preview/Development). |
| Cambios que no aparecen tras desplegar | Service worker de Flutter: recarga forzada o ventana privada. |
