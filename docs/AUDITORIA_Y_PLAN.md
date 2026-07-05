# Auditoría general y plan de mejoras — Event Radio App

> Documento de auditoría técnica y de producto sobre el estado actual del MVP.
> Objetivo del pedido: dejar la app **operativa y descargable en distintos
> celulares** (Android e iOS), con mejoras de funcionalidad, seguridad, UX/UI
> y todo lo necesario para un piloto real.
>
> Fecha: 2026-07-04 · Rama: `claude/radio-app-audit-plan-co6sjo`

---

## 1. Resumen ejecutivo

Event Radio es una app **Flutter + Supabase** para coordinación por radio en
eventos temporales: ingreso por código/QR, eventos con estados, canales,
push-to-talk (PTT), broadcast, SOS, historial reproducible y transcripción.

El proyecto está **bien estructurado** (arquitectura por features, capa de
dominio limpia, repositorio mock/real intercambiable, RLS pensada, Edge
Functions para tokens y transcripción, SQL versionado y tests de dominio). Es
un MVP sólido para **demo y validación de flujo**.

Sin embargo, **hoy no está listo para instalarse y usarse en celulares reales
en un evento**. Los bloqueantes principales son:

| # | Bloqueante | Impacto |
|---|-----------|---------|
| B1 | El audio en tiempo real (LiveKit) es un **esqueleto**; por defecto corre en modo *mock*. La función central de "radio" no transmite entre dispositivos. | Funcional — crítico |
| B2 | **Autenticación real no puede completarse en dispositivo**: se usa el deep link `eventradio://login-callback` pero no hay `intent-filter` (Android) ni `CFBundleURLTypes` (iOS). El login con Google / magic-link no vuelve a la app. | Funcional / Auth — crítico |
| B3 | **La app no es publicable**: `applicationId = com.example.event_radio_app`, el build de *release* se firma con **claves de debug**, ícono y splash por defecto de Flutter. | Distribución — crítico |
| B4 | **Tráfico en claro habilitado** (`usesCleartextTraffic=true`, `NSAllowsArbitraryLoads=true`). Necesario para LAN local, pero **bloquea la revisión de tiendas** y es riesgo en producción. | Seguridad / Distribución — alto |
| B5 | Sin **CI/CD** ni pipeline de build firmado; sin sincronización de estado en tiempo real (los cambios de admin no llegan solos a los participantes). | Operación — alto |

**Conclusión:** con el trabajo del plan de la sección 6 (estimado ~4–6
semanas de un dev), la app pasa de "demo local guiada" a "app instalable y
operativa para un piloto real de 3–20 personas".

---

## 2. Inventario técnico

- **Frontend:** Flutter (Dart `>=3.4`), Riverpod (estado), go_router (navegación),
  Material 3. ~7.900 líneas de Dart.
- **Backend:** Supabase (Postgres + Auth + Storage + Edge Functions Deno).
  8 migraciones SQL, RLS activa en todas las tablas, RPCs `security definer`.
- **Audio real-time:** LiveKit (cliente incluido, token vía Edge Function).
- **Transcripción:** Edge Function `transcribe-audio` → OpenAI o Whisper local.
- **Plataformas declaradas:** Android, iOS, Web.
- **Tests:** 5 archivos de test de dominio (códigos de invitación, modelos,
  repo mock, flujo join). Sin tests de widget ni de integración.
- **Dependencias sensibles:** `audioplayers`, `record`, `mobile_scanner`,
  `qr_flutter`, `permission_handler`, `livekit_client`, `supabase_flutter`.

**Fortalezas destacables**
- Separación mock/real por `EnvConfig`, con *fallback* automático a mock si
  falta configuración. Excelente para desarrollo y demo.
- RLS madura: funciones `security definer` para evitar recursión de políticas
  (migración 0004), validación de PTT solo en evento *operativo*, códigos de
  invitación nunca expuestos por búsqueda directa (RPC `accept_event_invite`).
- Generador de códigos con `Random.secure()` y alfabeto sin caracteres ambiguos.
- Contrato de datos ya preparado para audio real (storage_path, transcription_*,
  livekit_room_name).

---

## 3. Hallazgos por categoría

Severidad: 🔴 crítico · 🟠 alto · 🟡 medio · 🔵 bajo/mejora.

### 3.1 Funcionalidad

- 🔴 **F1 — Audio PTT real no funcional.** `MockAudioRoomService` es el
  default; `LiveKitAudioRoomService` existe pero el flujo real (publicar/
  suscribir por sala y canal, prioridad de emergencia, mezcla de escucha
  simultánea) está a medias. Sin esto, la "radio" no transmite entre teléfonos.
- 🔴 **F2 — Login real no cierra el ciclo en móvil** (ver B2). Deep link sin
  configurar. Además `SupabaseAccountController.continueWithGoogle` reporta
  éxito aunque el usuario nunca vuelva.
- 🟠 **F3 — Sin sincronización en tiempo real.** El admin crea/edita
  eventos, canales, participantes y permisos, pero los clientes no reciben
  esos cambios sin recargar. No se usan `supabase.channel()` / realtime ni
  *streams*. En un evento, un cambio de permisos debería propagarse solo.
- 🟠 **F4 — Persistencia real del CRUD admin sin validación de servidor
  completa.** Varias operaciones (crear/editar canal, participante) van
  directo por PostgREST confiando en RLS; conviene envolver operaciones
  compuestas (p. ej. crear participante + membresías) en RPCs transaccionales
  como ya se hizo con `create_event_with_admin`.
- 🟡 **F5 — SOS y broadcast dependen del historial, no de una señal push.**
  Hoy se insertan filas; no hay notificación/alerta sonora en vivo al resto.
- 🟡 **F6 — Sin manejo de reconexión / pérdida de red** en el flujo de audio
  ni reintentos de subida de audio (el `catch (_)` descarta el `storagePath`
  silenciosamente y solo deja un log).
- 🔵 **F7 — Sin notificaciones push** (FCM/APNs) para avisar inicio de evento,
  SOS o mensajes de canal crítico con la app en segundo plano.

### 3.2 Seguridad

- 🔴 **S1 — Credenciales de demo hardcodeadas en el cliente.**
  `SupabaseAccountController.continueAsLocalAdminDemo()` hace
  `signInWithPassword('admin@event-radio.test', 'event-radio-admin')`. Debe
  quedar **detrás de un flag de build de debug** y nunca compilarse en release.
- 🟠 **S2 — Tráfico en claro global** (ver B4). Restringir a dominios LAN
  concretos mediante *network security config* (Android) y excepciones ATS
  acotadas (iOS), no `NSAllowsArbitraryLoads`/`usesCleartextTraffic` globales.
- 🟠 **S3 — Sin rate-limiting / anti-abuso en `accept_event_invite`.** Los
  códigos de 12 caracteres son fuertes, pero no hay throttle ni bloqueo por
  intentos. Un atacante autenticado puede enumerar. Añadir límite por
  usuario/tiempo y contador de intentos fallidos.
- 🟡 **S4 — CORS `Access-Control-Allow-Origin: *`** en ambas Edge Functions.
  Restringir a los orígenes de la app (web) una vez publicada.
- 🟡 **S5 — `.env` se empaqueta como asset** (`assets: - .env`). Contiene solo
  `SUPABASE_URL` + `anon key` (público por diseño), pero conviene documentar
  explícitamente que **ningún secreto** (LiveKit/OpenAI) va en `.env` del
  cliente (ya se aclara en comentarios; reforzar con validación de build).
- 🟡 **S6 — Token LiveKit de vida corta (10 min) sin refresh** en cliente. Un
  evento largo cortará audio; falta lógica de renovación.
- 🔵 **S7 — `livekit-token` y `transcribe-audio` confían en RLS del `anon`
  client** con Authorization del usuario; correcto, pero conviene loggear/
  auditar accesos y validar `channel_id` como UUID antes de la RPC.

### 3.3 Experiencia de usuario (UX)

- 🟠 **U1 — Riesgo operativo del modo mock.** El banner `MODO MOCK`/`MODO REAL`
  es una buena práctica, pero un operador puede confundir una demo con
  coordinación real. En release, ocultar/bloquear el modo mock salvo build de
  demo explícito.
- 🟡 **U2 — Sin estados de carga/errores unificados** ni reintentos visibles en
  varias pantallas; el usuario no siempre sabe si una acción se guardó.
- 🟡 **U3 — Sin onboarding ni ayuda contextual** para roles nuevos
  (coordinador vs. participante vs. viewer).
- 🟡 **U4 — Accesibilidad:** faltan etiquetas semánticas, tamaños de toque
  garantizados para el botón PTT en uso con guantes/apuro, soporte de
  *screen reader* y contraste verificado.
- 🔵 **U5 — Sin soporte offline / modo degradado** cuando cae la red.
- 🔵 **U6 — Internacionalización:** todo el texto está en español embebido; no
  hay `intl`/ARB pese a que la dependencia `intl` ya está.

### 3.4 Interfaz (UI)

- 🟡 **I1 — Marca por defecto de Flutter:** ícono de app, splash, nombre y
  color del launcher sin personalizar (ver B3). Bloquea publicación con
  identidad propia.
- 🟡 **I2 — Tema único.** `AppTheme` existe pero conviene revisar soporte
  claro/oscuro, tipografía y jerarquía para uso en exteriores (alto brillo).
- 🔵 **I3 — El botón PTT** (elemento central) merece diseño dedicado: feedback
  háptico, animación de "transmitiendo", indicador de canal activo y de quién
  habla.
- 🔵 **I4 — Falta un panel "en vivo"** que muestre presencia (quién está
  conectado por canal) — hoy no hay presencia realtime.

### 3.5 Distribución móvil (descargable en distintos celulares)

- 🔴 **D1 — `applicationId` placeholder** `com.example.event_radio_app`. Play
  Store rechaza `com.example.*`. Definir un ID propio (p. ej.
  `com.eventradio.app`) y el *bundle identifier* iOS equivalente.
- 🔴 **D2 — Firma de release con claves de debug** (`signingConfig = debug`).
  Hay que crear un *keystore* de release (Android) y perfiles/certificados de
  distribución (iOS), idealmente vía CI con secretos.
- 🟠 **D3 — Sin `versionCode`/`versionName` gestionados** para tiendas; hoy
  heredan de Flutter. Definir versionado semántico y automatizar el `build+N`.
- 🟠 **D4 — Sin ícono ni splash** (ver I1). Usar `flutter_launcher_icons` y
  `flutter_native_splash`.
- 🟠 **D5 — Permisos y cumplimiento de tiendas:** declarar uso de micrófono
  con textos claros (ya están), completar *Data Safety* (Android) y
  *App Privacy* (iOS), política de privacidad y manejo de audio grabado.
- 🟡 **D6 — Cleartext global** (ver B4) puede hacer fallar la revisión.
- 🟡 **D7 — Sin canal de distribución para el piloto** (TestFlight / Play
  Internal Testing / APK firmado). Documentar el flujo de instalación.
- 🔵 **D8 — Tamaño y ABIs:** configurar `--split-per-abi` / App Bundle para
  reducir el APK y cubrir arm64/x86.

### 3.6 Backend / datos

- 🟡 **BK1 — Falta índice/limpieza de invitaciones expiradas** y job de
  expiración automática (hoy expira por consulta, no hay barrido).
- 🟡 **BK2 — `event_logs` puede crecer sin retención**; definir política de
  purga/retención.
- 🔵 **BK3 — Sin migración de *rollback*** documentada ni entorno *staging*
  formal separado de local.
- 🔵 **BK4 — La columna legacy `transcription`** convive con
  `transcription_text`; planificar su retiro.

### 3.7 Calidad / DevOps

- 🟠 **Q1 — Sin CI** (`.github/workflows` inexistente). No hay `flutter
  analyze`/`test`/`build` automáticos ni chequeo de RLS en cada PR.
- 🟡 **Q2 — Cobertura de tests limitada** al dominio; sin tests de widget,
  de repositorio Supabase (mockeado) ni de las Edge Functions.
- 🟡 **Q3 — Sin monitoreo/observabilidad** (Sentry/Crashlytics) para el piloto.
- 🔵 **Q4 — Sin `analysis_options` estricto** más allá de flutter_lints.

---

## 4. Matriz de priorización

| ID | Hallazgo | Severidad | Esfuerzo | Prioridad |
|----|----------|-----------|----------|-----------|
| B2/F2 | Deep link auth móvil | 🔴 | Bajo | **P0** |
| S1 | Password demo hardcodeado | 🔴 | Bajo | **P0** |
| D1/D2 | appId + firma release | 🔴 | Bajo-Medio | **P0** |
| B1/F1 | LiveKit audio real | 🔴 | Alto | **P0** |
| B4/S2/D6 | Cleartext → config de red acotada | 🟠 | Bajo | **P1** |
| D4/I1 | Ícono, splash, branding | 🟠 | Bajo | **P1** |
| F3 | Realtime sync | 🟠 | Medio | **P1** |
| Q1 | CI/CD | 🟠 | Medio | **P1** |
| S3 | Rate-limit invites | 🟠 | Medio | **P1** |
| F7/U4/D5 | Push, accesibilidad, cumplimiento tiendas | 🟡 | Medio | **P2** |
| U6/BK/Q | i18n, retención, observabilidad | 🟡/🔵 | Variado | **P3** |

---

## 5. Quick wins (bajo esfuerzo, alto valor)

1. Configurar deep link `eventradio://login-callback` en Android e iOS (P0).
2. Aislar `continueAsLocalAdminDemo` bajo `kDebugMode` / flag de compilación.
3. Definir `applicationId` y *bundle id* propios.
4. Generar ícono y splash con `flutter_launcher_icons` + `flutter_native_splash`.
5. Reemplazar cleartext global por *network security config* acotada a la IP LAN.
6. Añadir workflow CI con `flutter analyze && flutter test`.
7. Ocultar el modo mock en builds de release (dejar solo `--dart-define=DEMO=true`).

---

## 6. Plan por hitos para app operativa y descargable

> **Actualización:** este plan fue ampliado y reemplazado por
> [`PLAN_PREMIUM.md`](./PLAN_PREMIUM.md), que suma visión de producto premium,
> modelo de costos cero/mínimo, diseño, acceso, escalabilidad y monetización.
> Los hitos de abajo se conservan como referencia del alcance técnico original.

### Hito A — Publicable y con auth real (semana 1–2) · P0
- Deep links Android/iOS + verificar OAuth Google y magic-link end-to-end.
- `applicationId`/bundle id definitivos; *keystore* release + firma; ícono y
  splash; nombre y versión.
- Aislar credenciales/atajos de demo del build de release.
- *Network security config* acotada (quitar cleartext global).
- **Entregable:** APK/App Bundle firmado + build iOS en TestFlight, con login
  real funcionando en dispositivo.

### Hito B — Audio en tiempo real de verdad (semana 2–4) · P0
- Completar `LiveKitAudioRoomService`: publicar/suscribir por sala de canal,
  escucha simultánea, prioridad de emergencia, mute/PTT, renovación de token.
- Desplegar Edge Function `livekit-token` con secrets y LiveKit Cloud.
- Presencia por canal (quién está conectado / quién habla) vía LiveKit o
  Supabase Realtime.
- **Entregable:** dos teléfonos hablando por PTT y broadcast reales.

### Hito C — Operación robusta (semana 3–5) · P1
- Realtime sync de eventos/canales/permisos (Supabase Realtime).
- RPCs transaccionales para el CRUD admin compuesto.
- Rate-limit y auditoría de `accept_event_invite`.
- Reintentos de subida de audio y manejo de reconexión.
- Notificaciones push (FCM/APNs) para SOS y canal crítico.
- **Entregable:** un cambio de admin se refleja solo en los participantes; SOS
  llega con la app en segundo plano.

### Hito D — Calidad, cumplimiento y tiendas (semana 4–6) · P1/P2
- CI/CD: analyze, test, build firmado, y chequeo de RLS por PR.
- Observabilidad (Sentry/Crashlytics), tests de widget e integración.
- Accesibilidad, estados de carga/error unificados, i18n con `intl`/ARB.
- *Data Safety* / *App Privacy*, política de privacidad, retención de logs y
  audio, purga de invitaciones expiradas.
- **Entregable:** app en Play Internal Testing + TestFlight lista para piloto
  ampliado, con pipeline reproducible.

---

## 7. Recomendaciones de arquitectura a futuro

- Introducir una capa de *servicios de dominio* para orquestar audio + repo +
  logs (hoy el repositorio Supabase mezcla persistencia y reglas de negocio).
- Mover reglas compuestas críticas a RPCs `security definer` (menos confianza
  en el cliente, operaciones atómicas).
- Definir *feature flags* (`--dart-define`) para demo/piloto/producción en
  lugar del *fallback* implícito a mock.
- Formalizar entornos: `local` → `staging` → `prod` con proyectos Supabase
  separados y migraciones aplicadas por CI.

---

## 8. Próximos pasos sugeridos

1. Aprobar este plan y priorizar Hito A (desbloquea "descargable + login real").
2. Crear los issues por hallazgo (IDs de la sección 3) para seguimiento.
3. Comenzar por los *quick wins* de la sección 5, que ya habilitan una primera
   build firmada instalable en teléfonos del equipo.

> Este documento es la auditoría y el plan. La implementación de cada hito se
> puede abordar en PRs incrementales siguiendo la matriz de priorización.
