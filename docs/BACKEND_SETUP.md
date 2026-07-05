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

### 2. Redirect URL para login de organizadores (opcional)

Solo si vas a usar "Continuar con Google" / magic-link:

Dashboard → **Authentication → URL Configuration → Redirect URLs** → agregar
`eventradio://login-callback`.

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
