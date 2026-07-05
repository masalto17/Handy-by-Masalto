# Handy by Masalto (Event Radio App)

App Flutter de radio operativa para eventos — nombre comercial **Handy**.
MVP para validar el flujo operativo:
ingreso por codigo, eventos temporales, canales asignados, PTT LiveKit,
historial reproducible, transcripcion opcional, bitacora y CRUD admin.

Documentos clave:

- [`docs/AUDITORIA_Y_PLAN.md`](docs/AUDITORIA_Y_PLAN.md): auditoria general.
- [`docs/PLAN_PREMIUM.md`](docs/PLAN_PREMIUM.md): plan de producto premium.
- [`docs/RELEASE.md`](docs/RELEASE.md): builds firmados para Android/iOS,
  identidad de la app (`app.eventradio.mobile`), deep link de auth y modo demo
  (`--dart-define=DEMO=true`; en release los atajos demo quedan fuera).

## Estado del hito 1

- La app corre con datos mock por defecto y no necesita credenciales reales.
- La pantalla de ingreso incluye cuenta opcional mock: Gmail simulado o invitado.
- Todas las pantallas muestran `MODO MOCK` o `MODO REAL` para evitar confundir
  una demo local con operacion conectada a backend.
- El admin permite crear y editar eventos, canales, participantes y permisos por canal.
- Los eventos tienen fecha, hora, duracion, estados y bloqueo al cerrarse.
- Los participantes tienen codigo de invitacion y QR individual.
- El Push-To-Talk usa una capa `AudioRoomService`: mock por defecto y LiveKit
  real cuando estan configurados `LIVEKIT_AUDIO_ENABLED`, `LIVEKIT_URL` y la
  Edge Function de tokens.
- El historial puede reproducir audios guardados y transcribirlos via Edge
  Function con OpenAI o Whisper local.
- Supabase queda preparado con `.env.example`, repositorios conectables y SQL versionado.

## Arranque local

```sh
cd event_radio_app
cp .env.example .env
flutter pub get
flutter analyze
flutter test
flutter run -d chrome
```

Para publicar una preview estatica como la usada en este workspace:

```sh
flutter build web
cd build/web
python3 -m http.server 8080 --bind 127.0.0.1
```

Luego abrir `http://127.0.0.1:8080/`.

Para probar desde telefonos o computadoras en la misma Wi-Fi, usar el modo LAN:

```sh
scripts/start_lan_preview.sh
```

El script detecta la IP de la Mac, reconstruye web con
`SUPABASE_URL=http://IP-DE-LA-MAC:54321`, restaura `.env` y sirve la app en
`0.0.0.0:8081`. Abrir desde otros dispositivos:
`http://IP-DE-LA-MAC:8081/`. `127.0.0.1` solo funciona en la misma maquina.

## Codigos mock

- `SATI26`: coordinadora/admin con evento activo.
- `MARCOS26`: participante de seguridad.
- `ANA26`: participante de produccion.
- `JULIA26`: coordinadora tecnica.
- `CERRADO`: evento cerrado para probar bloqueo operativo.

## Flujo admin mock

Entrar con `SATI26`, abrir `Admin` y probar:

- Crear o editar evento con fecha, hora, duracion y estado.
- Crear, editar o eliminar canales.
- Crear, editar o eliminar participantes.
- Asignar a cada participante que canales escucha y en cuales puede hablar.
- Ver y copiar QR/codigo de invitacion por participante.
- Revisar el panel `Puesta en marcha` para decidir si el evento esta listo
  para un ensayo operativo chico.

Los formularios validan nombres, codigos, duracion y duplicados antes de guardar.
Al invitar participantes, el admin genera por defecto codigos aleatorios de 12
caracteres sin simbolos ambiguos. El boton de regenerar sirve para invalidar el
codigo anterior antes de compartir la invitacion.

El panel de puesta en marcha calcula un go/no-go basico con Supabase, LiveKit,
Whisper local, historial/playback, estado del evento, fecha/duracion, canales,
participantes, permisos, codigos unicos y canal critico.

## Cuenta opcional

El ingreso por codigo sigue siendo suficiente para el hito 1. La opcion
`Continuar con Gmail` es mock y sirve para validar la experiencia futura:
asociar una cuenta real con invitaciones, roles y recuperacion de acceso.
La integracion real se hara con Supabase Auth cuando existan credenciales.

## Advertencia para piloto

Mientras el banner diga `MODO MOCK`, la app sirve para demo guiada, capacitacion
y validacion de flujo. No sincroniza dispositivos, no persiste datos reales y
no debe usarse para coordinar personas durante un evento.

## Supabase

Cuando exista el proyecto real:

1. Copiar `.env.example` a `.env`.
2. Completar `SUPABASE_URL` y `SUPABASE_ANON_KEY`.
3. Configurar `AUTH_REDIRECT_URL` si el deep link de login cambia.
4. Aplicar las migraciones en orden:
   `0001_initial_event_radio_schema.sql`, `0002_auth_invite_linking.sql` y
   `0003_backend_hardening.sql`, `0004_rls_recursion_fix.sql`.
5. Si Supabase inicializa bien, la app usa automaticamente el repositorio real;
   si falta configuracion o falla la inicializacion, vuelve a mock.

El ingreso real por codigo usa Supabase Auth y la RPC `accept_event_invite`,
que vincula el codigo con `auth_user_id` sin exponer busquedas directas por
`invite_code` desde el cliente.

Para una prueba real, crear participantes desde Admin y compartir el QR/codigo
generado. Evitar codigos manuales cortos o faciles de adivinar.

La migracion `0003_backend_hardening.sql` agrega creacion transaccional de
evento/admin/canal inicial, expiracion y revocacion de invitaciones, validacion
servidor para PTT en evento activo, consistencia canal-participante y logs
operativos sin codigos de invitacion.

La migracion `0004_rls_recursion_fix.sql` mueve los checks de permisos de canal
a funciones `security definer` para evitar recursiones entre politicas RLS de
canales, membresias, mensajes y storage.

### Seed y RLS

Para validar Supabase local o staging:

```sh
scripts/start_supabase_local.sh
```

Ese script requiere Docker Desktop corriendo y Supabase CLI instalado. Luego:

```sh
SUPABASE_DB_URL=postgresql://postgres:postgres@127.0.0.1:54322/postgres \
  scripts/check_backend.sh
```

El script aplica migraciones si todavia no existen, carga
`supabase/seed_mvp.sql`, ejecuta `supabase/tests/rls_checks.sql` y corre
`flutter test`. El seed crea un evento piloto con Produccion, Seguridad,
Tecnica, Emergencia, admin, participantes y viewer con permisos diferenciados.

Por seguridad, `scripts/check_backend.sh` solo corre directo contra localhost.
Si se usa una base remota de staging, hay que habilitarlo de forma explicita:

```sh
ALLOW_REMOTE_DB_SEED=true SUPABASE_DB_URL="<staging-db-url>" \
  scripts/check_backend.sh
```

No ejecutar ese comando contra produccion: carga datos de prueba.

El modelo ya conserva campos para evolucionar a audio real:
`livekit_room_name`, `audio_url`, `storage_path`, `transcription_status`,
`transcription_text`, `transcription_provider` y `transcription_job_id`.

### Audio PTT / LiveKit

La UI de PTT ya llama a `AudioRoomService` antes de guardar el mensaje en el
repositorio. Sin configuracion extra se usa `MockAudioRoomService`, por lo que
la demo conserva el PTT simulado y el historial actual.

Para activar LiveKit PTT real:

1. Definir `LIVEKIT_AUDIO_ENABLED=true` y `LIVEKIT_URL` en `.env`.
2. Configurar secrets de Supabase Edge Functions:
   `LIVEKIT_URL`, `LIVEKIT_API_KEY`, `LIVEKIT_API_SECRET`.
3. Desplegar/servir la Edge Function `livekit-token`.
4. Usar `EventChannel.livekitRoomName` como sala por canal.
5. Para broadcast, la UI ya entrega todos los canales destino al servicio; el
   esqueleto abre/publica en cada sala objetivo.

LiveKit requiere permisos nativos de microfono. Android e iOS ya declaran el
permiso basico para PTT.

### Storage y transcripcion

El audio real se guarda en el bucket privado `event-audio` y el historial puede
pedir transcripcion para mensajes pendientes.

1. El cliente graba o recibe el audio final y lo sube al bucket privado
   `event-audio`.
2. El objeto debe guardarse con path
   `{event_id}/{channel_id}/{voice_message_id}.{extension}` para que las
   politicas de Storage puedan validar evento y canal.
3. El cliente crea el registro en `voice_messages` con `storage_path` o deja
   `audio_url` como compatibilidad temporal, `transcription_status = pending`
   y sin completar texto/proveedor/job.
4. La Edge Function `transcribe-audio` con service role toma mensajes por
   `channel_id` o por `message_ids`, envia el WAV a OpenAI o Whisper local,
   pasa por `processing`, y finalmente guarda `transcription_text`,
   `transcription_provider`, `transcription_job_id` y estado `completed` o
   `failed`.
5. La columna legacy `transcription` se mantiene solo para compatibilidad con
   datos/mock existentes. El campo canonico nuevo es `transcription_text`.

Al terminar un PTT, la app dispara la transcripcion en segundo plano para los
mensajes recien guardados. El boton `Transcribir` en Historial queda como
respaldo manual para reprocesar audios pendientes o fallidos. Si falla la
transcripcion, el audio sigue reproducible.

Las politicas RLS no permiten que el cliente final escriba transcripciones ni
metadatos del proveedor. Los usuarios autenticados solo pueden leer/subir audio
de eventos y canales donde tengan permiso, y solo pueden insertar mensajes PTT
propios en canales donde `can_talk = true`.

Variables necesarias para la funcion de transcripcion:

```sh
supabase secrets set OPENAI_API_KEY="<openai-api-key>"
supabase secrets set OPENAI_TRANSCRIPTION_MODEL="gpt-4o-mini-transcribe"
```

Para desarrollo local, incluir esas variables en el archivo usado con
`supabase functions serve`.

Alternativa sin costo por uso: Whisper local.

```sh
brew install whisper-cpp
mkdir -p .local/whisper-models
curl -L -o .local/whisper-models/ggml-base.bin \
  https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin
scripts/start_local_whisper.sh
```

En el archivo de entorno usado por `supabase functions serve`, definir:

```sh
LOCAL_WHISPER_URL=http://host.docker.internal:8787/transcribe
```

Con `LOCAL_WHISPER_URL` configurado, `transcribe-audio` usa `whisper.cpp`
local antes que OpenAI. El endpoint local tambien puede probarse directo:

```sh
curl -X POST http://127.0.0.1:8787/transcribe -F file=@audio.wav
```

## Runbook MVP piloto

Objetivo: probar con 3 a 5 personas durante 15 minutos, priorizando claridad de
audio, PTT simple, broadcast, SOS, historial y permisos por canal.

1. Iniciar Supabase local o usar Supabase cloud/staging.
2. Servir Edge Functions con los secrets necesarios:
   `LIVEKIT_URL`, `LIVEKIT_API_KEY`, `LIVEKIT_API_SECRET`,
   `SUPABASE_SERVICE_ROLE_KEY` y, para transcripcion gratis,
   `LOCAL_WHISPER_URL=http://host.docker.internal:8787/transcribe`.
3. Iniciar Whisper local con `scripts/start_local_whisper.sh` y validar
   `http://127.0.0.1:8787/transcribe`.
4. Iniciar la app con `flutter run -d chrome --web-port 8081` o construir web.
5. Entrar como admin, activar/extender el evento desde `Admin` y revisar
   `Puesta en marcha`.
6. Crear o revisar participantes: coordinador, produccion, seguridad, tecnica
   e invitado sin transmision.
7. Compartir QR/codigo individual. Para otros dispositivos no alcanza
   `127.0.0.1`; usar deploy temporal o tunel publico.
8. Validar: PTT por canal, broadcast, escucha simultanea, SOS, playback de
   audios anteriores y transcripcion automatica/manual.

Para un ensayo real fuera de esta maquina, usar Supabase cloud + LiveKit cloud y
publicar la app o tunelizarla. `127.0.0.1` solo funciona en el equipo local.

## App nativa en telefono

La app ya declara permisos de microfono, internet y red local para pruebas con
Supabase local/LAN. Para correrla en un telefono conectado:

```sh
scripts/run_lan_app.sh
```

Ese script detecta la IP de la Mac, recompila la app usando
`SUPABASE_URL=http://IP-DE-LA-MAC:54321` y restaura `.env` al salir.

Si hay mas de un dispositivo:

```sh
flutter devices
scripts/run_lan_app.sh -d <device-id>
```

Requisitos:

- iPhone/iPad: Xcode completo, CocoaPods instalado, dispositivo confiado y
  cuenta de desarrollo configurada en Xcode.
- Android: Android Studio + Android SDK instalados, depuracion USB habilitada.
- Ambos: estar en la misma red que la Mac si se usa Supabase local.

Para un piloto con telefonos reales, la app nativa es mejor que web local:
permite microfono sin depender de HTTPS del navegador.

## Verificacion

Comandos esperados antes de cerrar un cambio:

```sh
flutter analyze
flutter test
flutter build web
```

## Proximo hito recomendado

- Autenticacion real con Supabase Auth y vinculo por codigo de invitacion.
- Persistencia real del CRUD admin.
- Token backend para completar LiveKit PTT por canal y broadcast a todos los canales.
- Implementar el worker real de Storage/transcripcion sobre este contrato.
