# Event Radio — Plan Premium v2

> Evolución del plan de `AUDITORIA_Y_PLAN.md`. Objetivo: convertir Event Radio
> en una **app premium, intuitiva, segura y escalable** para la organización de
> eventos, festivales y recitales — **con costo de mantenimiento cero o mínimo**
> — descargable en **Android y iPhone**.
>
> Fecha: 2026-07-04 · Reemplaza la sección 6 del documento de auditoría.

---

## 1. Visión de producto

**"Walkie-talkie profesional para eventos, sin hardware."**

Cualquier organizador crea un evento en 1 minuto, invita a su equipo con un QR,
y todos se comunican por canales de radio con push-to-talk, broadcast y botón
SOS — con historial reproducible y transcripción. Sin comprar handies, sin
configurar nada, sin capacitación.

### Premisa central: intuitiva para cualquier persona

La regla de diseño de todo el producto: **cada rol tiene un camino de 3 toques
o menos para su acción principal.**

| Rol | Acción principal | Camino |
|-----|------------------|--------|
| Participante | Hablar por su canal | Escanear QR → mantener apretado el botón PTT |
| Participante | Pedir ayuda | Botón SOS siempre visible (1 toque + confirmación) |
| Organizador | Crear evento | Abrir app → "Crear evento" → compartir QRs |
| Organizador | Ver qué pasa | Pantalla "En vivo" con presencia y última actividad |

Consecuencias concretas:
- **El participante nunca configura nada.** El QR contiene todo: evento, canal,
  permisos. Escanear = estar adentro. Sin registro obligatorio, sin contraseña
  (auth anónima de Supabase vinculada al código de invitación — ya existe).
- **Una sola pantalla operativa** para el participante: canal activo, botón PTT
  gigante, quién habla ahora, SOS. Todo lo demás (historial, otros canales) a
  un swipe.
- **Cero jerga técnica** en la UI: "Hablar", "Escuchar", "Pedir ayuda",
  "Invitar" — nunca "canal LiveKit", "RLS", "transcripción pendiente".
- **Modo guiado para el organizador**: checklist de puesta en marcha (ya existe
  el panel go/no-go) convertido en asistente paso a paso con lenguaje simple.

---

## 2. Modelo de costos: cero o mínimo

Toda la infraestructura elegida tiene capa gratuita generosa y **nada que
mantener** (sin servidores propios, todo gestionado). Fuentes:
[precios Supabase](https://supabase.com/pricing) ·
[precios LiveKit](https://livekit.com/pricing) ·
[límites free tier Supabase 2026](https://uibakery.io/blog/supabase-pricing) ·
[free tier LiveKit 2026](https://agentdeals.dev/vendor/livekit).

### Costos fijos inevitables (distribución)

| Concepto | Costo | Nota |
|----------|-------|------|
| Google Play (cuenta developer) | **US$ 25 una sola vez** | Sin renovación |
| Apple Developer Program | **US$ 99 / año** | Único costo recurrente obligatorio para iPhone |

### Infraestructura por escenario

| Servicio | Capa gratis (2026) | Escenario piloto (1–3 eventos/mes, ≤20 personas) | Escenario producción |
|----------|--------------------|--------------------------------------------------|----------------------|
| **Supabase** (DB, Auth, Storage, Realtime, Edge Functions) | 500 MB DB, 1 GB storage, 5 GB egress, 50.000 MAU, 500.000 invocaciones de funciones, 200 conexiones realtime concurrentes | **$0** — sobra capacidad | Pro US$ 25/mes recién cuando haya eventos pagos |
| **LiveKit Cloud** (audio en vivo) | Plan Build: **5.000 minutos WebRTC/mes**, sin tarjeta | **$0** — un evento de 4 h × 15 personas ≈ 3.600 min de conexión; PTT real usa mucho menos si se conecta solo al hablar/escuchar activo | Ship US$ 50/mes o autohospedar (LiveKit es open source) |
| **Notificaciones push** (FCM + APNs vía FCM) | Gratis ilimitado | $0 | $0 |
| **Transcripción** | Web Speech API (browser, ya integrado) + Whisper on-device / whisper.cpp | **$0** — eliminar dependencia de OpenAI por defecto | $0; OpenAI solo como opción premium opt-in |
| **Crash reporting** (Sentry free / Firebase Crashlytics) | Gratis | $0 | $0 |
| **CI/CD** (GitHub Actions) | 2.000 min/mes gratis en repos privados; ilimitado en públicos | $0 | $0 |

**Total mantenimiento en piloto: US$ 0/mes** (+ US$ 99/año de Apple).
**Total en producción temprana: ~US$ 25–75/mes**, solo cuando ya hay uso real.

### Decisiones de diseño que protegen el costo cero

1. **PTT eficiente en minutos LiveKit**: conectarse a la sala solo mientras se
   habla o hay transmisión activa en el canal (no conexión permanente de todos
   a todas las salas). Esto multiplica ×5–10 la capacidad del free tier y es
   además mejor para batería.
2. **Transcripción sin API paga por defecto**: Web Speech (web) y
   speech-to-text nativo del teléfono (Android/iOS) como primera opción;
   whisper.cpp para el organizador que quiera procesar en su compu. OpenAI
   queda como opción explícita con su propia key.
3. **Retención automática de audio**: los audios de un evento se purgan N días
   después de cerrado (configurable, default 30). Mantiene el storage bajo
   1 GB indefinidamente y es además la política de privacidad correcta.
4. **Anti-pausa del proyecto Supabase free**: el free tier pausa proyectos tras
   7 días sin tráfico. Mitigación: un GitHub Action semanal gratuito hace un
   ping de salud. (Desaparece al pasar a Pro.)
5. **Sin backend propio**: toda la lógica de servidor vive en RPCs de Postgres
   y Edge Functions de Supabase. Nada que parchear, escalar ni monitorear a
   mano.

---

## 3. Mejoras de funcionalidad (qué hace la app premium)

### Núcleo (imprescindible para "solución real")

- **F-1 · Audio PTT real multi-dispositivo** (completa `LiveKitAudioRoomService`):
  hablar y escuchar por canal, broadcast a todos los canales, ducking del
  canal normal cuando habla el canal de emergencia, renovación de token.
- **F-2 · Presencia en vivo**: quién está conectado en cada canal y quién está
  hablando ahora (LiveKit ya lo provee; solo hay que exponerlo en UI).
- **F-3 · Sincronización realtime**: cambios de admin (permisos, canales,
  estado del evento) se propagan al instante vía Supabase Realtime. Nadie
  "recarga" nada.
- **F-4 · SOS de verdad**: notificación push + sonido de alerta + vibración a
  coordinadores aunque la app esté en segundo plano, con nombre y canal de
  quien la envió. Opcional: adjuntar ubicación (opt-in, solo durante el SOS).
- **F-5 · Notificaciones push** (FCM): inicio de evento, SOS, mensajes en canal
  crítico. Gratis e imprescindible para operación real.
- **F-6 · Audio en segundo plano**: seguir escuchando el canal con la pantalla
  bloqueada (servicio foreground Android / background audio iOS) — un handy
  que solo funciona con la pantalla prendida no sirve en un festival.

### Diferenciales premium

- **F-7 · Replay inteligente**: "¿qué me perdí?" — reproducir los últimos N
  mensajes del canal en orden, a 1.5×, con transcripción visible.
- **F-8 · Plantillas de evento**: festival, recital, evento corporativo,
  maratón — canales y roles pre-armados (Producción, Seguridad, Técnica,
  Emergencia). Crear un evento profesional en 1 minuto.
- **F-9 · Multi-evento**: un usuario (productora) con varios eventos activos y
  cambio rápido entre ellos. Base de la escalabilidad comercial.
- **F-10 · Informe post-evento**: al cerrar, generar resumen exportable
  (actividad por canal, SOS, timeline) — valor directo para el organizador.
- **F-11 · Modo degradado sin señal**: si se cae la red, la app lo dice claro,
  encola los PTT grabados y los sube al volver la conexión.

---

## 4. Diseño e interfaz premium

- **D-1 · Identidad visual propia**: nombre, ícono, splash, paleta y tipografía
  de marca. Estética "equipo de producción": oscura por defecto, alto
  contraste, acentos por color de canal.
- **D-2 · Design system con Material 3**: tokens de color/tipografía/espaciado,
  tema claro y oscuro, componentes reutilizables (tarjeta de canal, pill de
  estado, botón PTT). Coherencia total entre pantallas.
- **D-3 · El botón PTT como pieza central**: grande (mínimo 96 dp), anillo
  animado mientras se transmite, feedback háptico al iniciar/cortar, estados
  inconfundibles (listo / transmitiendo / sin permiso / sin red). Usable con
  guantes, bajo el sol, en movimiento.
- **D-4 · Pantalla "En vivo"** para coordinadores: presencia por canal, última
  actividad, SOS activos, accesos directos a broadcast.
- **D-5 · Accesibilidad real**: tamaños de toque ≥ 48 dp, etiquetas semánticas
  para lector de pantalla, contraste AA, soporte de tipografía dinámica del
  sistema, no depender solo del color para estados.
- **D-6 · Micro-onboarding por rol**: la primera vez, 3 pantallas máximo que
  muestran (no explican) cómo hablar, escuchar y pedir ayuda.
- **D-7 · i18n desde el inicio**: español e inglés con `intl`/ARB. El texto ya
  centralizado permite sumar idiomas sin tocar pantallas.

---

## 5. Acceso e identidad (simple y seguro a la vez)

- **A-1 · QR = acceso.** El flujo principal sigue siendo escanear y entrar,
  con auth anónima vinculada al código. Sin fricción para el 90% de usuarios.
- **A-2 · Cuenta opcional para organizadores** (Google / magic-link) que da
  recuperación de acceso y multi-evento. Requiere cerrar los deep links
  (`eventradio://` + App Links/Universal Links verificados con dominio).
- **A-3 · Links de invitación universales**: `https://eventradio.app/j/CODIGO`
  abre la app si está instalada o lleva a la tienda si no (deferred deep link).
  Un solo link/QR sirve para invitar e instalar. Un dominio cuesta ~US$ 12/año
  y puede servirse gratis desde GitHub Pages/Cloudflare Pages.
- **A-4 · Códigos con expiración y revocación** (ya existen) expuestos en UI
  clara para el organizador: "este QR vence el viernes", "revocar acceso".
- **A-5 · Roles simples en la superficie**: Organiza / Coordina / Participa /
  Solo escucha. La matriz fina de permisos por canal queda en "avanzado".

---

## 6. Seguridad (plan consolidado)

Hereda todos los hallazgos S1–S7 de la auditoría y los ordena en dos tandas:

**Antes de publicar (bloqueantes):**
1. Eliminar del build de release la credencial demo hardcodeada (S1) y todo el
   modo mock (solo accesible con `--dart-define=DEMO=true`).
2. Quitar cleartext global; HTTPS obligatorio, excepción LAN solo en debug (S2).
3. Rate-limit + auditoría de intentos en `accept_event_invite` (S3): máx. N
   intentos fallidos por usuario/hora, registrados en `event_logs`.
4. CORS de Edge Functions restringido al dominio propio (S4).
5. Renovación de token LiveKit antes de expirar (S6).

**Operación continua (costo cero):**
6. Purga automática de audio post-evento (privacidad + storage) vía `pg_cron`
   de Supabase (incluido gratis).
7. `supabase/tests/rls_checks.sql` corriendo en CI en cada PR — la RLS ya es
   buena; que no se rompa nunca.
8. Dependabot + `flutter pub outdated` en CI para dependencias vulnerables.
9. Secret scanning de GitHub activado (gratis).
10. Documento simple de privacidad: qué se graba, quién lo escucha, cuándo se
    borra. Obligatorio para tiendas y diferencial de confianza para clientes.

---

## 7. Escalabilidad

La arquitectura actual ya escala bien conceptualmente (todo multi-tenant por
`event_id` con RLS). Lo que falta es operativo:

- **E-1 · Entornos separados**: `staging` y `prod` como dos proyectos Supabase
  (el free tier permite 2 activos). Migraciones aplicadas solo por CI.
- **E-2 · Feature flags por `--dart-define`** (demo/staging/prod) en lugar del
  fallback implícito a mock.
- **E-3 · Camino de crecimiento sin re-arquitectura**:
  - 0–200 usuarios concurrentes → free tier tal cual.
  - 200+ concurrentes o eventos simultáneos grandes → Supabase Pro (US$ 25) y
    LiveKit Ship (US$ 50). Solo cambia el plan, no el código.
  - Escala mayor → LiveKit autohospedado (open source) sobre un VPS; la
    abstracción `AudioRoomService` ya aísla ese cambio.
- **E-4 · Índices y paginación**: historial y logs paginados por cursor (hoy
  traen todo); los índices ya existen.
- **E-5 · Observabilidad gratis**: Sentry/Crashlytics + logs de Edge Functions
  de Supabase. Alertas por mail sin costo.

---

## 8. Distribución Android + iPhone

1. **Identidad de app**: `applicationId`/bundle id propios (p. ej.
   `app.eventradio.mobile`), keystore de release Android y certificados de
   distribución iOS guardados como secretos de CI.
2. **CI/CD con GitHub Actions** (gratis): en cada tag, build firmado →
   **Play Internal Testing** y **TestFlight** automáticos (fastlane).
3. **Cumplimiento de tiendas**: Data Safety (Play) y App Privacy (App Store)
   declarando micrófono y audio grabado; política de privacidad publicada
   (GitHub Pages, gratis); textos de permisos ya escritos en español.
4. **Estrategia de lanzamiento**: piloto cerrado (Internal Testing/TestFlight,
   hasta 100 testers iOS sin revisión completa) → beta abierta → producción.
5. **Compatibilidad**: `minSdk` 23+ (cubre ~99% de Androids activos), iOS 13+;
   App Bundle con split por ABI para tamaño mínimo de descarga.

---

## 9. Monetización (opcional, para sostener el costo cero)

Sin cambiar el producto, el modelo natural es **freemium por evento**:

- **Gratis**: 1 evento activo, hasta 10 participantes, 2 canales — perfecto
  para eventos chicos y para probar.
- **Premium por evento o suscripción productora**: participantes ilimitados,
  canales ilimitados, plantillas, informe post-evento, retención extendida.

Esto financia Supabase Pro + LiveKit Ship con 1–2 clientes y mantiene la app
gratis para el usuario final invitado (que nunca paga: paga el organizador).

---

## 10. Hoja de ruta consolidada

| Fase | Contenido | Resultado | Costo infra |
|------|-----------|-----------|-------------|
| **1 · Instalable** (sem. 1–2) | Deep links + App/Universal Links, appId y firma, ícono/splash/marca, quitar demo hardcode y cleartext, CI analyze+test+RLS | APK/TestFlight firmados con login real en dispositivo | $0 |
| **2 · Radio real** (sem. 2–4) | LiveKit completo (F-1), presencia (F-2), conexión eficiente en minutos, renovación de token | Dos teléfonos hablando de verdad; free tier protegido | $0 |
| **3 · Operación seria** (sem. 4–6) | Realtime sync (F-3), push+SOS (F-4/F-5), audio en segundo plano (F-6), reintentos/cola offline (F-11), rate-limit invites | Piloto real en un evento chico | $0 |
| **4 · Premium & tiendas** (sem. 6–9) | Design system (D-1/D-2/D-3), onboarding, accesibilidad, i18n, plantillas (F-8), replay (F-7), cumplimiento tiendas, purga de audio, observabilidad | Publicada en Play Store + App Store | $0 (+US$ 25 Play + US$ 99/año Apple) |
| **5 · Crecimiento** (continuo) | Multi-evento (F-9), informe post-evento (F-10), freemium, staging/prod separados | Producto comercial escalable | US$ 0–75/mes según uso |

**Criterio de "terminado" de cada fase**: demo grabada en dos teléfonos reales
(un Android y un iPhone) ejecutando el flujo completo de la fase.

---

## 11. Qué NO hacer (para proteger simplicidad y costo)

- ❌ Backend propio (Node/servidores): todo cabe en Supabase + Edge Functions.
- ❌ Chat de texto, fotos, videos: es una radio; el foco es la voz. El texto
  aparece solo como transcripción.
- ❌ Registro obligatorio para participantes: el QR es la cuenta.
- ❌ Depender de APIs pagas por defecto (OpenAI): siempre debe existir el
  camino gratis.
- ❌ Panel web de administración separado en esta etapa: el admin móvil ya
  existe y duplica esfuerzo; la misma app Flutter puede compilarse a web si
  hiciera falta.
