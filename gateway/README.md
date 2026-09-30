# Puente HANDY ↔ handy UHF

Une un canal de HANDY con un handy UHF real. Los que tienen la app y los que
tienen equipo de radio quedan en la misma conversacion: lo que se habla por
PTT en el celular sale al aire, y lo que se habla por el aire entra al canal.

El puente corre en la misma maquina del predio que hospeda el servidor de
audio local (ver [`docs/SERVIDOR_LOCAL.md`](../docs/SERVIDOR_LOCAL.md)).

> **Antes de transmitir, leer [`docs/PUENTE_RADIO.md`](../docs/PUENTE_RADIO.md).**
> Poner un equipo a repetir audio en una frecuencia no es lo mismo que usar
> un handy: en Argentina requiere autorizacion de ENACOM, y comprar el equipo
> no es la autorizacion.

## Como entra al evento

Como un participante mas, con un codigo de invitacion: el mismo camino que
un celular. No usa `service_role` ni ninguna via privilegiada, le aplican las
mismas reglas de RLS, y aparece en la lista de presencia con el nombre que le
puso el admin — que es como el operador se entera de que el enlace con los
handies esta arriba.

En el panel de admin: crear un participante llamado, por ejemplo,
`Radio UHF`, con permiso de transmitir, y copiar su codigo.

## Instalacion

```bash
cd gateway
npm install
cp .env.example .env   # y completar
npm start
```

Requiere Node ≥22 (lo exige el cliente de Supabase) y las herramientas de ALSA (`arecord`, `aplay`), que en
Debian/Raspberry Pi OS vienen en `alsa-utils`.

Para que arranque solo con la maquina, hay un ejemplo de unidad systemd en
[`docs/PUENTE_RADIO.md`](../docs/PUENTE_RADIO.md).

## Como decide quien habla

Un handy es half-duplex: mientras transmite, su receptor esta sordo, y dos
equipos transmitiendo a la vez en la misma frecuencia se tapan. El puente
arbitra el canal (`src/radio-arbiter.js`):

- **El aire tiene prioridad.** Si un handy esta transmitiendo, el puente no
  enciende su transmisor aunque alguien apriete PTT en la app. Cortar una
  transmision a la mitad es lo que no puede pasar.
- **Cola de apertura** (`HANDY_LEAD_MS`): enciende el transmisor y espera
  antes de mandar audio. Sin eso se pierde la primera silaba, porque el
  transmisor tarda en levantar y los handies del otro lado tardan en abrir
  el squelch.
- **Cola de cierre** (`HANDY_TAIL_MS`): sostiene la portadora un instante
  despues de la ultima palabra, para no cortarla.
- **Tiempo maximo** (`HANDY_MAX_KEY_MS`): corta una transmision trabada.
  Los equipos reales tienen este limite; una transmision que no termina
  recalienta la etapa final y deja el canal mudo para todo el evento.
- **Nunca publica el audio del receptor mientras transmite**, que seria
  realimentacion.

Al perder la sala, o al recibir SIGINT/SIGTERM, lo primero que hace es
apagar el transmisor.

## Ajustar el squelch

Los umbrales dependen del handy y de la placa de sonido, asi que hay que
medirlos una vez por instalacion:

1. Con el handy encendido, el volumen en el punto de trabajo y **nadie
   hablando**, correr el puente y mirar el log: no deberia pasar a
   `receiving`. Si pasa, subir `HANDY_SQUELCH_OPEN`.
2. Que alguien hable por otro handy, flojo y desde lejos. Tiene que pasar a
   `receiving`. Si no, bajar `HANDY_SQUELCH_OPEN`.
3. `HANDY_SQUELCH_CLOSE` va en la mitad del de apertura. Es la histeresis:
   con un solo umbral, una voz que roza el limite abre y cierra decenas de
   veces por segundo y corta silabas.

## Tests

```bash
npm test
```

Cubren lo que decide el comportamiento en el aire: el arbitraje half-duplex,
el squelch, el troceo de audio, el accionamiento del PTT y la validacion de
la configuracion. El audio real y el hardware no se pueden simular aca: eso
se prueba con la lista de [`docs/PUENTE_RADIO.md`](../docs/PUENTE_RADIO.md).
