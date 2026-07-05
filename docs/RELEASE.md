# Guía de release — Handy (by Masalto)

Cómo generar builds firmados e instalables para Android y iPhone.
Corresponde a la Fase 1 del [Plan Premium](./PLAN_PREMIUM.md).

## Identidad de la app

- **Nombre visible:** Handy (Android `android:label`, iOS `CFBundleDisplayName`).
- **applicationId / bundle id:** `app.eventradio.mobile`
- **Deep link de auth:** `eventradio://login-callback` (configurado en
  `AndroidManifest.xml` y `Info.plist`). En Supabase Auth → URL Configuration,
  agregar `eventradio://login-callback` a *Redirect URLs*.
- **Ícono:** master en `assets/icon/app_icon.png` (1024×1024). Los tamaños de
  Android (`mipmap-*`) y iOS (`AppIcon.appiconset`) ya están generados desde
  ese master; si se cambia el diseño, regenerarlos desde el master.

## Modo demo

Los atajos de demo (código prellenado, botón "admin demo", tarjeta de códigos
mock) **no existen en builds de release**. Para una demo guiada:

```sh
flutter build apk --dart-define=DEMO=true
```

En debug siempre están disponibles.

## Android

### 1. Crear el keystore de release (una sola vez)

```sh
keytool -genkey -v -keystore ~/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

### 2. Crear `android/key.properties` (NO se versiona)

```properties
storeFile=/ruta/absoluta/upload-keystore.jks
storePassword=********
keyAlias=upload
keyPassword=********
```

### 3. Build

```sh
flutter build appbundle --release        # para Play Store
flutter build apk --release              # para instalar directo (sideload)
```

Sin `key.properties`, el build de release cae a la firma de debug para que
`flutter run --release` siga funcionando en desarrollo. **Nunca subir a Play
un build firmado con debug.**

### Red

Release solo permite HTTPS (`network_security_config.xml`). El HTTP en claro
hacia Supabase local/LAN funciona únicamente en builds de debug.

## iOS

1. Abrir `ios/Runner.xcworkspace` en Xcode.
2. En *Signing & Capabilities*, elegir el team de la cuenta Apple Developer
   (US$ 99/año) y verificar el bundle id `app.eventradio.mobile`.
3. `flutter build ipa --release` y subir con Xcode Organizer o Transporter.
4. Distribuir por **TestFlight** (hasta 100 testers internos sin revisión
   completa).

ATS: HTTPS obligatorio; solo se permite HTTP dentro de la red local
(`NSAllowsLocalNetworking`) para pruebas con Supabase local.

## Version web (online, sin instalar nada)

El workflow **Deploy Web** (`.github/workflows/deploy-web.yml`) compila
`flutter build web` y publica el resultado en **Vercel** (gratis) en cada
push a `main`, o a demanda desde la pestaña Actions.

Requiere un unico secret nuevo en el repo:

- `VERCEL_TOKEN`: crear en https://vercel.com/account/tokens y cargarlo en
  Settings → Secrets and variables → Actions.

Usa los mismos secrets del backend real (`SUPABASE_URL`, `SUPABASE_ANON_KEY`,
`LIVEKIT_URL`) que el Build APK. La URL publica queda en el resumen de la
corrida (Actions → la corrida → "Summary").

Limitacion a tener en cuenta: el microfono en el navegador movil es mas
restrictivo que en la app instalada (requiere HTTPS siempre y el sistema
puede bloquearlo con la pantalla apagada). Para uso real en un evento, la
app instalada (APK/TestFlight) es la opcion confiable; la web sirve para
demos rapidas o para quien no puede instalar un APK.

## Checklist previo a subir a tiendas

- [ ] `flutter analyze && flutter test` en verde (CI lo exige en cada PR).
- [ ] Build sin `--dart-define=DEMO=true`.
- [ ] `SUPABASE_URL` apunta a proyecto cloud (HTTPS), no a IP local.
- [ ] Redirect URL registrada en Supabase Auth.
- [ ] Versión (`pubspec.yaml` → `version: x.y.z+N`) incrementada.
- [ ] Data Safety (Play) / App Privacy (App Store) declaran micrófono y audio
      grabado; política de privacidad publicada.
- [ ] Purga de audio activa: agendar la Edge Function `purge-event-audio`
      (service role) para borrar audio de eventos cerrados hace más de 30 días.
