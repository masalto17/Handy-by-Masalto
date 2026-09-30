# Servidor de audio local (modo predio / sin internet)

HANDY habla con un servidor LiveKit para el audio en tiempo real. Por defecto
usa el de la nube que viene compilado en el build (`LIVEKIT_URL`). En un predio
con internet malo o sin internet, ese enlace es el punto unico de falla: si se
cae, se cae la radio.

Este documento explica como levantar un LiveKit en la red del predio y apuntar
los equipos a el desde la propia app, sin recompilar y sin depender del backend.

## Que resuelve y que no

Resuelve:

- El audio PTT viaja por la LAN del predio, sin salir a internet.
- Si internet se cae en medio del evento, la voz sigue funcionando.

No resuelve (por ahora):

- El historial, los participantes y los logs siguen yendo a Supabase. Sin
  internet se siguen grabando y quedan en la cola de reenvio (`PttOutbox`), que
  los sube cuando el enlace vuelve. La voz en vivo no se pierde; el registro
  llega con retraso.
- Los equipos tienen que estar en la misma red (mismo WiFi / mismo router).

## 1. Maquina del predio

Sirve cualquier PC, notebook o Raspberry Pi 4 conectada por cable al router del
WiFi que usan los equipos. Requisitos: Docker y una IP fija en la LAN (fijala
en el router por MAC, para que no cambie en medio del evento).

Anota esa IP. En los ejemplos usamos `192.168.1.50`.

## 2. Levantar LiveKit

```bash
mkdir -p ~/handy-livekit && cd ~/handy-livekit

cat > livekit.yaml <<'YAML'
port: 7880
rtc:
  tcp_port: 7881
  port_range_start: 50000
  port_range_end: 50200
  use_external_ip: false
keys:
  # Generar con: openssl rand -hex 16 (clave) y openssl rand -hex 32 (secreto)
  APIxxxxxxxxxxxx: SECRETOxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
YAML

docker run -d --name handy-livekit --restart unless-stopped \
  --network host \
  -v "$PWD/livekit.yaml:/livekit.yaml" \
  livekit/livekit-server --config /livekit.yaml
```

`--network host` evita tener que mapear el rango UDP a mano. En Windows o macOS
hay que publicar los puertos explicitamente (`-p 7880:7880 -p 7881:7881
-p 50000-50200:50000-50200/udp`).

Comprobacion rapida desde otra maquina de la misma red:

```bash
curl -i http://192.168.1.50:7880
# Responde algo de LiveKit (no "connection refused").
```

Si no responde, es el firewall de la maquina: hay que abrir 7880/TCP,
7881/TCP y 50000-50200/UDP.

## 3. Tokens

La app pide el token de sala a la edge function `livekit-token` de Supabase.
Esa function firma con los secrets `LIVEKIT_API_KEY` y `LIVEKIT_API_SECRET`.
Para que los tokens sirvan contra el servidor del predio, **la clave y el
secreto de `livekit.yaml` tienen que ser los mismos que los secrets de
Supabase**:

```bash
supabase secrets set LIVEKIT_API_KEY=APIxxxxxxxxxxxx
supabase secrets set LIVEKIT_API_SECRET=SECRETOxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

Los tokens de LiveKit no llevan la direccion del servidor: solo identidad,
sala y permisos. Por eso el mismo token vale para la nube y para el predio, y
alcanza con cambiar la URL en la app.

Consecuencia operativa: **hay que pedir los tokens antes de quedarse sin
internet**. En la practica, que cada equipo entre al canal una vez con internet
al empezar el evento.

## 4. Apuntar los equipos al servidor local

En cada dispositivo, panel de admin → tarjeta **Servidor de audio**:

1. Escribir `ws://192.168.1.50:7880`.
2. Tocar **Usar servidor local**.
3. La tarjeta queda en verde indicando la URL en uso.

Para volver a la nube, **Volver a la nube**. La eleccion queda guardada en el
dispositivo y sobrevive al reinicio de la app.

Notas:

- El esquema es `ws://` (o `wss://` si pusiste un certificado). `http://` no
  sirve: LiveKit habla WebSocket.
- En la web, un sitio servido por `https://` **no** puede abrir `ws://` (el
  navegador lo bloquea por contenido mixto). En el predio, entonces: la app
  Android contra `ws://`, o un `wss://` con certificado valido si hace falta el
  navegador.
- La configuracion es por dispositivo. Si un equipo queda apuntado a la nube y
  el resto al local, ese equipo no escucha a los demas. Conviene verificarlo en
  la prueba de sonido, antes de que arranque el evento.

## 5. Checklist de prueba, el dia anterior

1. Levantar la maquina y verificar que responde el `curl`.
2. Dos telefonos en el WiFi del predio, ambos apuntados a la IP local.
3. PTT de uno a otro: tiene que escucharse.
4. Cortar internet del router (dejando el WiFi) y repetir: tiene que seguir
   escuchandose.
5. Devolver internet y comprobar que el historial se completa solo.

## Camino siguiente

Esta misma maquina es la que despues hospeda el puente con los handies UHF
reales (Motorola EP450, Baofeng BF-888S): un gateway RoIP que entra a la sala
LiveKit como un participante mas. Por eso conviene dejarla instalada y fija.
