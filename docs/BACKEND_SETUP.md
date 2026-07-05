# Backend de Handy — estado y pasos restantes

Estado del backend cloud provisto para el piloto. Complementa
[`docs/RELEASE.md`](./RELEASE.md).

## Proyecto Supabase (ya creado y configurado)

- **Proyecto:** `handy` · organización de tu cuenta.
- **Región:** São Paulo (`sa-east-1`) — menor latencia para LatAm.
- **Ref:** `ootloeyokctgqonxqwon`
- **URL:** `https://ootloeyokctgqonxqwon.supabase.co`
- **Clave publicable (anon):** `sb_publishable_C340BwTSVYYwDExLW1XB7A_7QJZARcg`
  (es pública por diseño; el acceso real lo controla RLS).

Ya aplicado automáticamente:

- Las 10 migraciones (esquema, RLS, RPCs, hardening).
- Edge Function `livekit-token` desplegada (ACTIVE).
- Realtime habilitado en las tablas del evento.
- Advisor de seguridad revisado: sin accesos indebidos para `anon`.
- **Evento de prueba sembrado** para usar la app de una: código de
  invitación **`HANDY2026`** (queda como coordinador/admin el primero que
  entre), canales *Producción* y *Emergencia*, activo por 8 horas.

## Pasos manuales que faltan (no automatizables por API)

### 1. Habilitar ingreso anónimo (CRÍTICO)

La app vincula el código de invitación a una sesión anónima de Supabase. En
proyectos nuevos el ingreso anónimo viene **desactivado**.

Dashboard → **Authentication → Sign In / Providers → Anonymous** → activar.

Sin esto, ingresar por código/QR falla.

### 2. "Continuar con Gmail" — opcional, hoy no funciona sin este paso

El botón "Continuar con Gmail" necesita el proveedor Google **configurado en
Supabase** (Client ID/Secret de un proyecto de Google Cloud Console), que no
está hecho. Sin eso, el botón siempre falla — no es un bug del código, es un
paso manual pendiente:

1. Crear credenciales OAuth en Google Cloud Console.
2. Dashboard Supabase → **Authentication → Providers → Google** → cargar
   Client ID/Secret y activar.
3. Dashboard → **Authentication → URL Configuration → Redirect URLs** →
   agregar `eventradio://login-callback`.

**No es necesario para crear eventos.** Cualquier persona ya puede tocar
"¿Sos organizador? Crea tu evento" en la pantalla de ingreso y armar su
propio evento sin código ni cuenta de Google — usa la misma sesión anónima
que el ingreso por código. Gmail queda como mejora opcional para recuperar
acceso desde otro dispositivo.

### 3. LiveKit (audio real) — cuenta gratis + secrets

El audio PTT en vivo usa LiveKit. Es gratis (5.000 min/mes) y no requiere
tarjeta.

1. Crear cuenta en https://cloud.livekit.io y un proyecto.
2. Copiar **URL del proyecto** (formato `wss://xxxx.livekit.cloud`), **API
   Key** y **API Secret**.
3. Cargar los secrets de la Edge Function (Dashboard Supabase → **Edge
   Functions → Secrets**, o CLI):
   - `LIVEKIT_URL` = la URL wss del proyecto
   - `LIVEKIT_API_KEY`
   - `LIVEKIT_API_SECRET`
4. Para que la app active LiveKit, en el build real definir en el entorno:
   - `LIVEKIT_AUDIO_ENABLED=true`
   - `LIVEKIT_URL=wss://xxxx.livekit.cloud`

Sin LiveKit configurado, la app funciona igual pero el PTT queda simulado
(mock); todo lo demás (ingreso, canales, permisos, SOS, historial) opera
real contra Supabase.

### 4. Transcripción de audio — requiere una clave paga o Whisper propio

La Edge Function `transcribe-audio` ya está desplegada (ACTIVE), pero **sin
configurar todavía**: sin uno de estos dos secrets, cada intento de
transcribir falla con "Falta configurar LOCAL_WHISPER_URL u
OPENAI_API_KEY".

- **Opción paga (más simple):** cuenta OpenAI + `supabase secrets set
  OPENAI_API_KEY=...`. Cuesta centavos de dólar por minuto de audio
  (`gpt-4o-mini-transcribe`).
- **Opción gratis (requiere un servidor propio):** correr `whisper.cpp`
  (ver `scripts/start_local_whisper.sh`) y cargar `LOCAL_WHISPER_URL`
  apuntando a ese servidor. Solo sirve mientras ese servidor esté prendido
  y accesible desde internet — no es "gratis y automático", alguien tiene
  que mantenerlo corriendo.
- **Ya funciona gratis, pero solo en Handy Web:** el navegador transcribe
  con su propio reconocimiento de voz (Web Speech API) sin pasar por esta
  función. En el **APK** (Android/iPhone) no hay equivalente nativo hoy, así
  que ahí la transcripción depende sí o sí de una de las dos opciones de
  arriba.

## APK que apunta al backend real

El workflow **Build APK** (pestaña Actions → *Run workflow*) puede compilar
un APK conectado a este backend. Para eso, cargar en el repo estos **secrets**
(Settings → Secrets and variables → Actions):

| Secret | Valor |
|--------|-------|
| `SUPABASE_URL` | `https://ootloeyokctgqonxqwon.supabase.co` |
| `SUPABASE_ANON_KEY` | `sb_publishable_C340BwTSVYYwDExLW1XB7A_7QJZARcg` |
| `LIVEKIT_URL` | (opcional) `wss://xxxx.livekit.cloud` cuando tengas LiveKit |

Luego correr **Build APK** con la opción *demo* **desmarcada** → descargar el
artifact `handy-apk`. Con la opción *demo* marcada, el APK sale en modo mock
(sin backend) para evaluar la interfaz.

## Probar de punta a punta

1. Habilitar ingreso anónimo (paso 1).
2. Instalar el APK real (o `flutter run` con el `.env` apuntando a la URL/clave
   de arriba).
3. Ingresar con el código **`HANDY2026`** → quedás como coordinador.
4. Desde **Admin**: crear canales, invitar participantes (cada uno con su QR),
   asignar permisos. Los cambios se sincronizan en vivo.
5. Compartir códigos/QR con otras personas para probar PTT, broadcast y SOS.
