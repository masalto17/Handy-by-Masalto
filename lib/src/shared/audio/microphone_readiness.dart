import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

/// Estado del permiso de microfono de este dispositivo.
enum MicrophoneReadiness {
  /// Todavia no se consulto, o la plataforma no permite consultarlo sin
  /// pedirlo (el navegador pregunta recien al usar el microfono).
  unknown,

  /// Permiso concedido: el PTT puede tomar el microfono sin interrupciones.
  ready,

  /// Falta el permiso, pero se puede pedir desde la app.
  needsGrant,

  /// Denegado de forma permanente: hay que habilitarlo desde los ajustes
  /// del sistema, la app ya no puede volver a preguntar.
  blocked;

  /// `true` si conviene resolverlo antes de que el operador tenga que hablar.
  bool get needsAttention =>
      this == MicrophoneReadiness.needsGrant ||
      this == MicrophoneReadiness.blocked;
}

/// Verifica el permiso de microfono al entrar al canal.
///
/// Sin esto, el permiso se pide recien cuando el operador aprieta PTT por
/// primera vez, que puede ser justo durante una emergencia: el dialogo del
/// sistema se come el momento en que habia que hablar. Consultarlo al
/// entrar permite resolverlo con calma.
class MicrophoneReadinessController extends StateNotifier<MicrophoneReadiness> {
  /// Crea el controlador. [checkStatus] y [requestPermission] se inyectan
  /// en tests para no depender del plugin de plataforma.
  MicrophoneReadinessController({
    Future<PermissionStatus> Function()? checkStatus,
    Future<PermissionStatus> Function()? requestPermission,
    bool? isWeb,
  })  : _checkStatus = checkStatus ?? (() => Permission.microphone.status),
        _requestPermission =
            requestPermission ?? (() => Permission.microphone.request()),
        _isWeb = isWeb ?? kIsWeb,
        super(MicrophoneReadiness.unknown);

  final Future<PermissionStatus> Function() _checkStatus;
  final Future<PermissionStatus> Function() _requestPermission;
  final bool _isWeb;

  /// Traduce el estado del plugin al del dominio.
  static MicrophoneReadiness readinessFor(PermissionStatus status) {
    if (status.isGranted || status.isLimited) return MicrophoneReadiness.ready;
    if (status.isPermanentlyDenied || status.isRestricted) {
      return MicrophoneReadiness.blocked;
    }
    return MicrophoneReadiness.needsGrant;
  }

  /// Consulta el permiso sin pedirlo, para no interrumpir al entrar.
  Future<void> refresh() async {
    // En el navegador consultar el permiso sin usarlo no es confiable y
    // puede disparar un prompt inesperado: se deja en unknown y el flujo
    // normal del PTT lo resuelve.
    if (_isWeb) {
      state = MicrophoneReadiness.unknown;
      return;
    }
    try {
      state = readinessFor(await _checkStatus());
    } catch (_) {
      // Plataforma sin soporte: no bloquear la pantalla por esto.
      state = MicrophoneReadiness.unknown;
    }
  }

  /// Pide el permiso explicitamente, a pedido del operador.
  Future<void> request() async {
    try {
      state = readinessFor(await _requestPermission());
    } catch (_) {
      state = MicrophoneReadiness.unknown;
    }
  }

  /// Abre los ajustes del sistema cuando el permiso quedo bloqueado.
  Future<void> openSettings() => openAppSettings();
}

/// Estado del permiso de microfono para la pantalla de canal.
final microphoneReadinessProvider =
    StateNotifierProvider<MicrophoneReadinessController, MicrophoneReadiness>(
  (ref) => MicrophoneReadinessController(),
);
