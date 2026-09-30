# Puente con handies UHF reales

En la mayoria de los eventos conviven dos mundos: los que tienen la app en el
celular y los que llevan el handy de siempre. Hoy son dos redes separadas y
alguien tiene que hacer de traductor a viva voz. El puente los une: un equipo
en el predio entra al canal de HANDY como un participante mas y, del otro
lado, esta cableado a un handy UHF que transmite y recibe en la frecuencia
que ya usa el equipo de produccion.

El codigo esta en [`gateway/`](../gateway/README.md). Este documento cubre lo
que no es software: lo legal, el hardware y la puesta en marcha.

## 1. Lo legal, primero

Un handy suelto y un equipo que repite audio automaticamente en una
frecuencia no son la misma cosa, ni para la fisica ni para el regulador.

En Argentina el espectro lo administra **ENACOM**. Operar en frecuencias UHF
de uso profesional requiere autorizacion para esas frecuencias y ese uso.
Dos cosas que conviene tener claras antes de encender nada:

- **Que el equipo venga programado de fabrica no es una autorizacion.** Un
  BF-888S sale con 16 canales cargados; que transmita no significa que esos
  canales esten habilitados para quien lo usa.
- **Un puente permanente no es un handy mas.** Queda transmitiendo sin
  operador presente y repite lo que venga de la red, lo que cambia el
  encuadre respecto de un equipo de mano.

Que hacer, en orden:

1. Averiguar bajo que servicio y con que frecuencias opera hoy la produccion
   del evento. Si ya hay una autorizacion vigente, el puente tiene que
   quedar dentro de ese permiso.
2. Consultar a ENACOM el caso concreto antes de operar al aire.
3. **Todas las pruebas tecnicas de este documento se pueden hacer sin salir
   al aire**: con los equipos a minima potencia, a un metro de distancia, o
   con carga fantasma. Conviene dejar la prueba en el aire para el final,
   cuando lo legal ya este resuelto.

Nada de esto es opcional ni es tramite menor: una interferencia en la
frecuencia equivocada puede pisar a un servicio de emergencia.

## 2. Hardware

### La maquina

La misma del servidor de audio local: Raspberry Pi 4/5 o cualquier PC con
Linux, por cable al router del predio. Si ya esta instalada para el modo sin
internet, no hace falta otra.

### El handy donante

De los dos equipos disponibles, **el Baofeng BF-888S es el mejor candidato
para quedar cableado al puente**, y el Motorola EP450 el mejor para quedar en
mano de la gente:

| | BF-888S | EP450 |
|---|---|---|
| Conector de audio | Kenwood 2 pines (muy comun, cables baratos) | Motorola, accesorio propio |
| Costo de dejarlo fijo | Bajo | Alto: es el equipo bueno |
| Programacion | CHIRP | Software de Motorola |

**No asumir que el cable del BF-888S sirve para el EP450.** Los conectores
son distintos, y forzarlo daña el equipo.

### La interfaz de audio

Se necesita una placa de sonido USB y una interfaz entre la placa y el handy.
Tres caminos, de menos a mas trabajo:

1. **Cable comercial de interfaz** para Kenwood 2 pines (los que se venden
   para modos digitales). Es lo mas rapido y lo mas dificil de romper.
2. **Placa USB + transformadores de aislacion 1:1 + divisor resistivo** en la
   salida. La salida de linea de una placa es mucho mas fuerte que lo que
   espera la entrada de microfono de un handy: sin atenuar, el audio sale
   saturado e ininteligible.
3. **Circuito propio** con optoacoplador para el PTT.

> **Antes de conectar nada, verificar el pinout del equipo concreto** con su
> hoja de servicio y un multimetro. Los pinouts publicados en foros varian
> entre versiones del mismo modelo, y una conexion equivocada puede dañar el
> handy o la placa de sonido. Si hay dudas, empezar por el camino 1.

### El PTT

Dos opciones, y el puente soporta las dos:

- **VOX** (`HANDY_PTT_MODE=vox`): el handy transmite solo al detectar audio.
  No hay que cablear nada mas. A cambio recorta el arranque de cada frase y
  el puente pierde la capacidad de cortar una transmision trabada. Sirve para
  la primera prueba.
- **Comando** (`HANDY_PTT_MODE=command`, recomendado): el puente enciende y
  apaga el transmisor. Un GPIO de la Raspberry contra un optoacoplador, o un
  rele USB. Se configura con `HANDY_PTT_KEY_CMD` / `HANDY_PTT_UNKEY_CMD`, asi
  que sirve cualquier hardware que se pueda accionar con un comando.

## 3. Leer la programacion de los handies

Antes de programar nada, hay que saber que tienen cargado hoy: frecuencia de
recepcion, de transmision y tono CTCSS/DCS del canal que usa la produccion.
Sin el tono correcto, el puente escucha pero nadie lo escucha (o al reves).

Con [CHIRP](https://chirpmyradio.com/) y el cable de programacion del BF-888S:

1. `Radio → Download From Radio`. **Solo descargar.**
2. Guardar el archivo. Es la copia de seguridad de la programacion de
   fabrica: si algo sale mal, es lo unico que permite volver atras.
3. Anotar, del canal en uso: RX, TX, y `Tone`/`TSQL` con su valor en Hz.

**No usar `Upload To Radio` hasta tener resuelto el punto 1 de este
documento.** Una subida equivocada deja el equipo mudo o transmitiendo donde
no corresponde.

Para el EP450 hace falta el software de programacion de Motorola; es otro
proceso y conviene hacerlo con quien administra esos equipos.

## 4. Backend: una migracion y un redeploy

El puente necesita el rol `gateway`, que se agrega en la migracion
`0012_gateway_participant_role.sql`, y el permiso de publicar atributos, que
se otorga en la edge function `livekit-token`. Hay que aplicar las dos cosas
antes de crear el participante del puente:

```bash
supabase db push
supabase functions deploy livekit-token
```

Sin la migracion, el panel de admin rechaza el rol; sin el redeploy, el
puente funciona pero la app no muestra su estado.

## 5. Puesta en marcha

Hace falta Node ≥22 (lo exige el cliente de Supabase); en Raspberry Pi OS,
desde [NodeSource](https://github.com/nodesource/distributions).

```bash
sudo apt install -y alsa-utils
arecord -l    # anotar tarjeta y dispositivo de la placa USB
aplay -l

cd gateway
npm install
cp .env.example .env    # completar con lo anotado
npm start
```

El log va diciendo el estado del canal: `idle`, `receiving` (un handy tiene
el canal), `keying`/`keyed` (el puente esta transmitiendo), `lockout` (se
corto una transmision por tiempo maximo). Ese mismo estado aparece en la
pantalla de canal de la app, asi que el operador no depende de mirar el log
de la maquina del predio.

### Como servicio

```ini
# /etc/systemd/system/handy-gateway.service
[Unit]
Description=Puente HANDY <-> handy UHF
After=network-online.target sound.target

[Service]
Type=simple
User=handy
WorkingDirectory=/opt/handy/gateway
EnvironmentFile=/opt/handy/gateway/.env
ExecStart=/usr/bin/node src/index.js
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

`Restart=always` importa: si el proceso muere, systemd lo vuelve a levantar y
el puente reentra al canal solo. Al salir, el puente apaga el transmisor antes
que ninguna otra cosa.

## 6. Prueba, en este orden

Cada paso agrega una sola variable. Si algo falla, se sabe que fue.

1. **Sin radio.** Puente andando con la placa USB en bucle (salida a entrada).
   Hablar por PTT desde un celular: el log tiene que pasar a `keyed`.
2. **Radio sin antena, minima potencia, a un metro.** Hablar desde el celular:
   se tiene que escuchar en el otro handy, claro y sin saturar. Si satura,
   atenuar mas la salida.
3. **Al reves.** Hablar por el handy: tiene que entrar al canal de la app.
   Ajustar el squelch con la receta del [README del puente](../gateway/README.md).
4. **Los dos a la vez.** Que alguien hable por el handy mientras otro aprieta
   PTT en la app: el puente **no** tiene que pisar al handy. En la pantalla
   de canal se tiene que ver el estado cambiando.
5. **Prueba de tiempo maximo.** Dejar un celular transmitiendo largo: el log
   tiene que llegar a `lockout` y el transmisor apagarse.
6. **Recien ahi, al aire**, con lo legal resuelto.

## 7. Lo que todavia no hace

- **Un puente por canal.** Cada canal de HANDY que se quiera puentear
  necesita su propia instancia y su propio handy donante, porque el aire es
  uno solo por frecuencia.
- **No hay identificacion por voz** de quien habla desde la app: los del
  handy escuchan la voz, pero el canal no anuncia el nombre.
- **El historial no guarda lo que vino del aire** como mensaje individual:
  entra a la sala en vivo, pero el puente no graba por separado cada
  transmision de radio.
- **Sin historial del estado del puente.** El operador ve el estado actual
  en la pantalla de canal, pero la bitacora del evento no registra todavia
  cuando el enlace estuvo caido.
