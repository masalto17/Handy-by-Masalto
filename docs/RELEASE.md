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

### 4. Firmar los APK que genera el CI

El workflow **Build APK** firma con la clave de release si encuentra estos
cuatro secrets del repo (Settings → Secrets and variables → Actions):

| Secret | Contenido |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | El `.jks` completo, codificado en base64 |
| `ANDROID_KEYSTORE_PASSWORD` | La `storePassword` del keystore |
| `ANDROID_KEY_ALIAS` | El alias (`upload` si se siguió el paso 1) |
| `ANDROID_KEY_PASSWORD` | La `keyPassword` de esa clave |

Para obtener el valor de `ANDROID_KEYSTORE_BASE64`:

```sh
base64 -w0 ~/upload-keystore.jks     # Linux
base64 -i ~/upload-keystore.jks      # macOS
```

Copiar la salida completa (una sola línea) y pegarla como valor del secret.

Cada corrida deja en su **Summary** con qué clave quedó firmado el APK. Si los
secrets están cargados pero el APK sale con firma de debug, el workflow falla
en lugar de publicar un artefacto engañoso.

### Por qué importa firmar desde el principio

La firma es la identidad de la app para Android. Android solo permite
actualizar una app instalada si el APK nuevo está firmado con **la misma**
clave. Consecuencias prácticas:

- Si hoy distribuís APK firmados con debug y mañana cambiás a release, **todos
  los operadores tienen que desinstalar y reinstalar**, perdiendo sesión.
- Si perdés el keystore, no podés volver a actualizar esa app nunca más: hay
  que publicar una app nueva con otro `applicationId`.

Por eso: **guardá `upload-keystore.jks` y sus contraseñas en un gestor de
contraseñas o caja fuerte, con al menos una copia fuera de la máquina donde
se generó.** No va al repositorio (`.gitignore` ya bloquea `*.jks`,
`*.keystore` y `android/key.properties`).

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

### Una sola ruta de deploy (y por que)

Vercel puede publicar de dos formas distintas, y **solo una esta activa**:

| Ruta | Estado | De donde saca la config |
|---|---|---|
| GitHub Actions (`deploy-web.yml`) | **Activa** | Secrets del repo |
| Integracion Git de Vercel (`scripts/vercel-build.sh`) | **Apagada** | Env vars del proyecto Vercel |

La integracion Git esta apagada en `vercel.json` (`git.deploymentEnabled:
false`) porque el proyecto Vercel no tiene cargadas `SUPABASE_URL` ni
`SUPABASE_ANON_KEY`: publicaba previews que arrancaban en "Configuracion de
Supabase ausente", en URLs que parecian validas. Un preview roto confunde
mas de lo que aporta.

Para recuperar los previews por PR: cargar `SUPABASE_URL`,
`SUPABASE_ANON_KEY` y `LIVEKIT_URL` en Vercel → Settings → Environment
Variables (entorno Preview) y volver `deploymentEnabled` a `{ "main": false }`.
El build avisa en su log si falta alguna, asi que se nota enseguida.

### El `.env` de la web es publico

`flutter_dotenv` empaqueta el `.env` como asset, de modo que queda servido en
`/assets/.env` y **cualquiera puede leerlo**. Eso esta bien para los valores
que ya son publicos por diseno (la URL de Supabase y la clave
`sb_publishable_`/anon, que se protegen con RLS, y la URL de LiveKit).

**Nunca** poner ahi una `service_role` key, un secret de LiveKit ni ninguna
credencial que no pueda ser publica: en web no hay forma de ocultarla. Esos
valores van como secrets de las Edge Functions de Supabase.

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
