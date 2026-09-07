# HANDY by MasAlto

Radio operativa Push-to-Talk para coordinación de eventos. Flutter multi-plataforma (web, Android, iOS) con LiveKit para audio en tiempo real y Supabase como backend.

## Stack

- **Flutter** ≥3.32 / Dart ≥3.4 — `pubspec.yaml` fija el SDK
- **Riverpod** para estado — providers en `lib/src/shared/data/event_radio_providers.dart`
- **GoRouter** — rutas en `lib/src/app/router.dart`
- **LiveKit** — audio PTT real, `lib/src/shared/audio/audio_room_service.dart`
- **Supabase** — auth anónimo, RLS, realtime, edge functions, storage de audio
- **Vercel** — deploy web (`deploy-web.yml`)

## Estructura del proyecto

```
lib/
  main.dart                         # Punto de entrada
  src/
    app/
      event_radio_app.dart          # MaterialApp + BootstrapError check
      router.dart                   # GoRouter con todas las rutas
    core/
      config/
        app_bootstrap.dart          # Inicialización dotenv + Supabase
        env_config.dart             # Variables de entorno (.env)
      theme/
        app_theme.dart              # Colores y tema
    features/
      admin/                        # Panel admin del evento
      auth/                         # Cuenta y autenticación
      channel/                      # Pantalla de canal PTT
        domain/ptt_state.dart       # Máquina de estados PTT
        presentation/
          channel_screen.dart       # UI del canal con presencia
          push_to_talk_button.dart  # Botón PTT con estados explícitos
      event/                        # Home del evento
      history/                      # Historial de mensajes de voz
      join/                         # Ingreso por código / QR
    shared/
      audio/
        audio_room_service.dart     # LiveKit rooms + reconexión + ducking
        ptt_audio_recorder.dart     # Grabación local del PTT
        live_speech_transcriber.dart # Speech-to-text en browser
      data/
        event_radio_providers.dart  # Providers Riverpod centrales
        supabase_event_radio_repository.dart
        mock_event_radio_repository.dart
        session_realtime.dart       # Suscripciones Supabase Realtime
      domain/
        event_models.dart           # Modelos: Event, Channel, Participant, etc.
        event_radio_repository.dart # Interface del repositorio
      presentation/
        bootstrap_error_screen.dart # Pantalla de error de inicialización
supabase/
  migrations/                       # 11 migraciones SQL (schema + RLS)
  functions/                        # Edge functions: livekit-token, transcribe-audio, purge-event-audio
  config.toml                       # Config local de Supabase
  seed_mvp.sql                      # Seed de datos de prueba
```

## Comandos

```bash
# Crear archivo de entorno para desarrollo local
cp .env.example .env

# Instalar dependencias
flutter pub get

# Generar localizaciones (obligatorio antes de analyze/build)
flutter gen-l10n

# Análisis estático
flutter analyze

# Tests
flutter test

# Build web
flutter build web

# Build APK
flutter build apk --release

# Build APK en modo demo (sin backend)
flutter build apk --release --dart-define=DEMO=true
```

## Modo demo vs producción

- `DEMO=true` (dart-define) + `kDebugMode`: habilita `allowDemoShortcuts`, fallback a `MockEventRadioRepository` si Supabase no está configurado.
- Release sin `DEMO`: requiere `SUPABASE_URL` y `SUPABASE_ANON_KEY`. Fallo de init muestra `BootstrapErrorScreen` en lugar de operar silenciosamente con datos mock.

## Audio PTT

El ciclo de Push-to-Talk sigue una máquina de estados explícita (`PttPhase`):
1. **idle** → listo
2. **requesting** → negociando permisos + conectando sala LiveKit
3. **transmitting** → micrófono publicando audio
4. **finalizing** → guardando grabación, transcripción, historial
5. **error** → fallo en requesting (permite reintentar)

Emergency ducking: cuando alguien habla en un canal de emergencia, se silencian automáticamente los demás canales.

Reconexión: 3 intentos con backoff exponencial (2s, 4s, 6s). Si falla, emite `ReconnectionFailure` con SnackBar + retry visible.

## CI

- **ci.yml** — `flutter analyze` + `flutter test` + `flutter build web` en cada push/PR
- **build-apk.yml** — APK Android (dispatch manual o tag `v*`), modo demo o real
- **deploy-web.yml** — Build web + deploy a Vercel en push a main

Los tres workflows usan `channel: stable` (sin pin de versión). Las dependencias del proyecto (en particular `record`) requieren Dart ≥3.12, por lo que Flutter stable actual es el mínimo funcional.

## Convenciones

- Idioma del código: inglés para identificadores, español para UI y comentarios
- Tests en `test/` reflejando la estructura de `lib/src/`
- Archivo `.env` **nunca** se commitea — `.env.example` sirve de plantilla
- Los secrets de LiveKit y OpenAI van como secrets de Supabase Edge Functions, no en la app
