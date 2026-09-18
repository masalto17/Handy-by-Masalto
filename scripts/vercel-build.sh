#!/usr/bin/env bash
#
# Build de Flutter web para Vercel.
#
# La integracion Git de Vercel clona el repo y corre este script en cada push
# y cada PR (preview). Vercel no trae Flutter preinstalado, asi que lo bajamos
# aca antes de compilar.
#
# El deploy de produccion sigue haciendose desde deploy-web.yml (GitHub
# Actions), que compila con los secrets del repo. Este script cubre los
# previews por PR y toma la configuracion de las env vars del proyecto Vercel.
set -euo pipefail

FLUTTER_CHANNEL="${FLUTTER_CHANNEL:-stable}"
FLUTTER_DIR="${FLUTTER_DIR:-$HOME/flutter}"

if [ ! -x "$FLUTTER_DIR/bin/flutter" ]; then
  echo "==> Instalando Flutter SDK ($FLUTTER_CHANNEL)"
  git clone --depth 1 --branch "$FLUTTER_CHANNEL" \
    https://github.com/flutter/flutter.git "$FLUTTER_DIR"
fi

export PATH="$FLUTTER_DIR/bin:$PATH"
# El contenedor de build corre como root y Flutter pide el opt-in explicito.
export FLUTTER_ROOT="$FLUTTER_DIR"

flutter --version

# En un preview no hay dominio fijo: VERCEL_URL trae el host de este deploy.
default_redirect="https://${VERCEL_URL:-localhost}/"

# Sin SUPABASE_URL/SUPABASE_ANON_KEY el build igual compila, pero la app
# arranca en la pantalla de error de configuracion en vez de la de ingreso.
# Antes eso solo se descubria abriendo el preview y viendo el error: aca
# queda asentado en el log de build, junto con como arreglarlo.
# Con `set -e`, un `[ ... ] && arr+=(...)` cuyo test da falso devuelve 1 y
# aborta el script: por eso van como `if` y no como cortocircuito.
missing_vars=()
if [ -z "${SUPABASE_URL:-}" ]; then
  missing_vars+=("SUPABASE_URL")
fi
if [ -z "${SUPABASE_ANON_KEY:-}" ]; then
  missing_vars+=("SUPABASE_ANON_KEY")
fi

if [ ${#missing_vars[@]} -gt 0 ]; then
  echo ""
  echo "############################################################"
  echo "## ATENCION: faltan variables de entorno del proyecto     ##"
  echo "############################################################"
  echo "## Sin configurar: ${missing_vars[*]}"
  echo "##"
  echo "## Este deploy va a compilar y publicarse, pero la app va"
  echo "## a mostrar 'Configuracion de Supabase ausente' en lugar"
  echo "## de la pantalla de ingreso: no tiene backend al que"
  echo "## conectarse."
  echo "##"
  echo "## Se cargan en Vercel -> Settings -> Environment"
  echo "## Variables, para el entorno de este deploy (Preview y/o"
  echo "## Production). Son los mismos valores que los secrets del"
  echo "## repo en GitHub."
  echo "############################################################"
  echo ""
else
  echo "==> Backend configurado: SUPABASE_URL y SUPABASE_ANON_KEY presentes"
fi

if [ -z "${LIVEKIT_URL:-}" ]; then
  # No impide operar (historial, bitacora y SOS siguen andando), pero el
  # PTT no transmite: conviene que no sorprenda en el evento.
  echo "==> AVISO: sin LIVEKIT_URL, el PTT de este deploy NO transmite audio."
else
  echo "==> Audio en vivo habilitado (LIVEKIT_URL presente)"
fi

echo "==> Generando .env desde las env vars del proyecto"
{
  echo "SUPABASE_URL=${SUPABASE_URL:-}"
  echo "SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY:-}"
  echo "AUTH_REDIRECT_URL=${AUTH_REDIRECT_URL:-$default_redirect}"
  if [ -n "${LIVEKIT_URL:-}" ]; then
    echo "LIVEKIT_AUDIO_ENABLED=true"
    echo "LIVEKIT_URL=${LIVEKIT_URL}"
  else
    echo "LIVEKIT_AUDIO_ENABLED=false"
    echo "LIVEKIT_URL="
  fi
} > .env

echo "==> flutter pub get"
flutter pub get

echo "==> flutter gen-l10n"
flutter gen-l10n

echo "==> flutter build web --release"
flutter build web --release

# El SDK web de passkeys no pasa por el bundler de Flutter.
cp web/bundle.js build/web/bundle.js

echo "==> Build listo en build/web"
