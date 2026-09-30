/// Resultado de validar la URL de un servidor de audio local.
enum AudioServerUrlIssue {
  /// El texto esta vacio.
  empty,

  /// No se pudo interpretar como URL.
  malformed,

  /// El esquema no es `ws://` ni `wss://`.
  wrongScheme,

  /// Falta el host.
  missingHost,
}

/// Donde se conecta el audio en vivo de esta instalacion.
///
/// Por defecto se usa el servidor de la nube que viene del `.env` del build.
/// En un predio sin internet confiable, el operador puede apuntar a un
/// servidor LiveKit corriendo en la red local: el PTT sigue funcionando
/// aunque se caiga el enlace a internet, y los mensajes quedan en la cola
/// de reenvio hasta que vuelva.
///
/// Esa misma maquina local es la que despues puede hospedar el puente con
/// handies UHF, asi que la URL local es el punto de entrada de ambas cosas.
class AudioServerSetting {
  /// Crea la configuracion.
  const AudioServerSetting({this.localUrl});

  /// URL del servidor local (`ws://` o `wss://`), o `null` para usar la nube.
  final String? localUrl;

  /// Sin URL local configurada: se usa el servidor del `.env`.
  static const cloud = AudioServerSetting();

  /// `true` si hay un servidor local configurado.
  bool get usesLocalServer => localUrl != null && localUrl!.isNotEmpty;

  /// URL efectiva a usar, dado el [cloudUrl] que trae el build.
  ///
  /// La local tiene prioridad: si el operador la configuro, es porque el
  /// enlace a la nube no es confiable en ese predio.
  String effectiveUrl(String cloudUrl) => usesLocalServer ? localUrl! : cloudUrl;

  /// `true` si hay algun servidor al que conectarse (local o de nube).
  bool hasAnyServer(String cloudUrl) => effectiveUrl(cloudUrl).isNotEmpty;

  /// Valida una URL de servidor local. Devuelve `null` si es utilizable.
  ///
  /// LiveKit habla WebSocket, asi que solo `ws://` y `wss://` sirven. En un
  /// predio sin certificado, `ws://` es lo normal; la advertencia sobre
  /// navegadores (que bloquean `ws://` desde una pagina https) se da en la
  /// UI, no aca: en la app instalada funciona igual.
  static AudioServerUrlIssue? validate(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return AudioServerUrlIssue.empty;

    final uri = Uri.tryParse(trimmed);
    if (uri == null) return AudioServerUrlIssue.malformed;
    if (uri.scheme != 'ws' && uri.scheme != 'wss') {
      return AudioServerUrlIssue.wrongScheme;
    }
    if (uri.host.isEmpty) return AudioServerUrlIssue.missingHost;
    return null;
  }

  /// Normaliza lo que escribio el operador (espacios, barra final).
  static String normalize(String value) {
    final trimmed = value.trim();
    return trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }

  AudioServerSetting copyWith({String? localUrl, bool clearLocal = false}) {
    return AudioServerSetting(
      localUrl: clearLocal ? null : (localUrl ?? this.localUrl),
    );
  }
}
