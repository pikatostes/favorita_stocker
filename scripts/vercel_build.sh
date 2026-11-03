#!/usr/bin/env bash
# Compila la app web en Vercel pasando las claves de Supabase.
#
# Vercel no lee `env.json` (está ignorado por Git) y `String.fromEnvironment`
# solo recibe valores en tiempo de compilación, así que hay que pasarlos como
# `--dart-define`. Las variables se definen en el proyecto de Vercel:
#
#     SUPABASE_URL
#     SUPABASE_PUBLISHABLE_KEY
#
# Solo es la clave publicable. La clave secreta nunca se usa en el cliente.
set -euo pipefail

if [ -z "${SUPABASE_URL:-}" ] || [ -z "${SUPABASE_PUBLISHABLE_KEY:-}" ]; then
  echo "Faltan SUPABASE_URL y/o SUPABASE_PUBLISHABLE_KEY en las variables de entorno." >&2
  echo "Defínelas en Vercel → Settings → Environment Variables." >&2
  exit 1
fi

# Si el paso de instalación clona el SDK dentro del repo, se usa esa copia;
# si Vercel ya trae `flutter` en el PATH, se usa el del sistema.
FLUTTER_BIN="flutter"
if [ -x "flutter/bin/flutter" ]; then
  FLUTTER_BIN="flutter/bin/flutter"
fi

"$FLUTTER_BIN" build web --release \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_PUBLISHABLE_KEY="$SUPABASE_PUBLISHABLE_KEY"
