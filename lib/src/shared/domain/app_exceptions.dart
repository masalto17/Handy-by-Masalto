/// Codigos tipados para errores de autenticacion.
enum AuthErrorCode {
  /// No se pudo iniciar el flujo OAuth de Google.
  googleSignInFailed,

  /// El email proporcionado es invalido o esta vacio.
  invalidEmail,

  /// El acceso demo no esta habilitado en esta build.
  demoUnavailable,
}

/// Excepcion para errores de autenticacion de la app.
///
/// Nombrada [AppAuthException] para evitar colision con el [AuthException]
/// de Supabase/GoTrue.
class AppAuthException implements Exception {
  const AppAuthException(this.code, {this.serverMessage});

  final AuthErrorCode code;
  final String? serverMessage;

  String get message => serverMessage ?? code.name;

  @override
  String toString() => message;
}

/// Codigos tipados para errores de operaciones sobre eventos.
///
/// Cubren los casos que antes usaban [StateError] con mensajes en español
/// hardcodeados: SOS, creacion de eventos, transcripcion, etc.
enum EventOperationErrorCode {
  /// El evento no esta en estado operativo (intento de SOS fuera de horario).
  eventNotOperational,

  /// El participante no tiene permiso suficiente para la operacion.
  insufficientPermission,

  /// No se pudo crear el evento en el backend.
  eventCreateFailed,

  /// La transcripcion de audios fallo.
  transcriptionFailed,

  /// No se pudo generar un codigo unico.
  codeGenerationFailed,

  /// El audio solicitado no esta disponible.
  audioUnavailable,
}

/// Excepcion para operaciones de negocio sobre eventos.
///
/// Reemplaza los [StateError] con mensajes hardcodeados por errores tipados
/// que la capa de presentacion puede mapear a cadenas i18n.
class EventOperationException implements Exception {
  /// Crea la excepcion con un [code] tipado y un [serverMessage] opcional.
  const EventOperationException(this.code, {this.serverMessage});

  /// Codigo tipado del error.
  final EventOperationErrorCode code;

  /// Mensaje original del servidor (diagnostico/fallback).
  final String? serverMessage;

  /// Descripcion legible — preferir [code] para mapeo i18n.
  String get message => serverMessage ?? code.name;

  @override
  String toString() => message;
}
