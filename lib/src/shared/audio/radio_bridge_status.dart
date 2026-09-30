import 'dart:convert';

/// Que esta haciendo el puente con los handies UHF en este momento.
///
/// Es la misma maquina de estados que corre el puente
/// (`gateway/src/radio-arbiter.js`); aca solo se interpreta lo que informa.
enum RadioBridgeState {
  /// Conectado, con el canal de aire libre.
  idle,

  /// Un handy esta transmitiendo: su voz entra al canal.
  receiving,

  /// El puente esta transmitiendo al aire lo que se habla en el canal.
  transmitting,

  /// Se corto una transmision por exceder el tiempo maximo.
  ///
  /// Es el aviso que importa: alguien quedo con el PTT trabado, o un
  /// microfono abierto tomo el canal de aire.
  lockout,

  /// El puente esta en la sala pero todavia no informo su estado.
  unknown;

  /// `true` si hay audio cruzando el puente ahora mismo.
  bool get isPassingAudio =>
      this == RadioBridgeState.receiving || this == RadioBridgeState.transmitting;

  /// `true` si el operador tiene que enterarse sin buscarlo.
  bool get needsAttention => this == RadioBridgeState.lockout;
}

/// Estado de un puente de radio presente en un canal.
class RadioBridgeStatus {
  /// Crea el estado.
  const RadioBridgeStatus({
    required this.name,
    required this.state,
    this.timeouts = 0,
  });

  /// Nombre que le puso el admin al participante del puente.
  final String name;

  /// Que esta haciendo ahora.
  final RadioBridgeState state;

  /// Cuantas transmisiones se cortaron por tiempo maximo desde que arranco.
  final int timeouts;

  /// Clave del atributo con el estado.
  static const stateAttribute = 'bridge_state';

  /// Clave del atributo con la cuenta de cortes por tiempo maximo.
  static const timeoutsAttribute = 'bridge_timeouts';

  /// Valor del rol que identifica a un puente.
  static const gatewayRole = 'gateway';

  /// Lee el estado de un participante de la sala, o `null` si no es un puente.
  ///
  /// El rol se toma de [metadata], que viaja firmada en el token: un
  /// participante comun no puede hacerse pasar por puente. Los atributos, en
  /// cambio, los escribe el propio puente, y solo a ese rol se le da permiso
  /// de escribirlos.
  static RadioBridgeStatus? fromParticipant({
    required String name,
    required String? metadata,
    required Map<String, String> attributes,
  }) {
    if (_roleFromMetadata(metadata) != gatewayRole) return null;

    return RadioBridgeStatus(
      name: name,
      state: _stateFromValue(attributes[stateAttribute]),
      timeouts: int.tryParse(attributes[timeoutsAttribute] ?? '') ?? 0,
    );
  }

  static String? _roleFromMetadata(String? metadata) {
    if (metadata == null || metadata.isEmpty) return null;
    try {
      final decoded = jsonDecode(metadata);
      if (decoded is! Map<String, dynamic>) return null;
      final role = decoded['role'];
      return role is String ? role : null;
    } on FormatException {
      // Metadata que no es JSON: no alcanza para tratarlo como puente.
      return null;
    }
  }

  static RadioBridgeState _stateFromValue(String? value) {
    switch (value) {
      case 'idle':
        return RadioBridgeState.idle;
      case 'receiving':
        return RadioBridgeState.receiving;
      // El puente distingue tres momentos de la transmision (encendido del
      // transmisor, audio, cola). Para el operador son lo mismo: esta al aire.
      case 'keying':
      case 'keyed':
      case 'tail':
        return RadioBridgeState.transmitting;
      case 'lockout':
        return RadioBridgeState.lockout;
      default:
        return RadioBridgeState.unknown;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is RadioBridgeStatus &&
      other.name == name &&
      other.state == state &&
      other.timeouts == timeouts;

  @override
  int get hashCode => Object.hash(name, state, timeouts);

  @override
  String toString() =>
      'RadioBridgeStatus(name: $name, state: $state, timeouts: $timeouts)';
}
