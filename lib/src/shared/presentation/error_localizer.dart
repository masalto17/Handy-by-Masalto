import 'package:event_radio_app/l10n/app_localizations.dart';
import 'package:event_radio_app/src/shared/audio/audio_room_service.dart';
import 'package:event_radio_app/src/shared/domain/app_exceptions.dart';
import 'package:event_radio_app/src/shared/domain/event_radio_repository.dart';

/// Mapea excepciones tipadas a cadenas i18n.
///
/// Centraliza la traduccion de errores de la capa de datos/dominio
/// a mensajes legibles por el usuario, evitando que los repositorios
/// contengan strings hardcodeados en algun idioma.
class ErrorLocalizer {
  const ErrorLocalizer._();

  /// Devuelve el mensaje i18n para una [JoinEventException].
  ///
  /// Si el servidor envio un mensaje propio (codigo [JoinErrorCode.unknown]),
  /// lo usa como fallback.
  static String joinError(AppLocalizations l10n, JoinEventException e) {
    switch (e.code) {
      case JoinErrorCode.emptyCode:
        return l10n.errorEmptyCode;
      case JoinErrorCode.codeNotFound:
        return l10n.errorCodeNotFound;
      case JoinErrorCode.sessionExpired:
        return l10n.errorSessionExpired;
      case JoinErrorCode.authRequired:
        return l10n.errorAuthRequired;
      case JoinErrorCode.inviteFailed:
        return e.serverMessage ?? l10n.errorInviteFailed;
      case JoinErrorCode.unknown:
        return e.serverMessage ?? l10n.joinError;
    }
  }

  /// Devuelve el mensaje i18n para una [AudioRoomConfigurationException].
  static String audioError(
    AppLocalizations l10n,
    AudioRoomConfigurationException e,
  ) {
    switch (e.code) {
      case AudioRoomErrorCode.invalidTokenResponse:
        return l10n.errorInvalidTokenResponse;
      case AudioRoomErrorCode.tokenFetchFailed:
        return e.serverMessage ?? l10n.errorTokenFetchFailed;
      case AudioRoomErrorCode.microphoneDenied:
        return l10n.errorMicrophoneDenied;
      case AudioRoomErrorCode.pttStartFailed:
        return l10n.pttAudioStartError;
    }
  }

  /// Devuelve el mensaje i18n para una [EventOperationException].
  static String operationError(
    AppLocalizations l10n,
    EventOperationException e,
  ) {
    switch (e.code) {
      case EventOperationErrorCode.eventNotOperational:
        return l10n.errorEventNotOperational;
      case EventOperationErrorCode.insufficientPermission:
        return l10n.errorInsufficientPermission;
      case EventOperationErrorCode.eventCreateFailed:
        return l10n.createEventError;
      case EventOperationErrorCode.transcriptionFailed:
        return e.serverMessage ?? l10n.errorTranscriptionFailed;
      case EventOperationErrorCode.codeGenerationFailed:
        return l10n.errorCodeGenerationFailed;
      case EventOperationErrorCode.audioUnavailable:
        return l10n.historyPlaybackError;
    }
  }

  /// Devuelve el mensaje i18n para una [AppAuthException].
  static String authError(AppLocalizations l10n, AppAuthException e) {
    switch (e.code) {
      case AuthErrorCode.googleSignInFailed:
        return l10n.errorGoogleSignInFailed;
      case AuthErrorCode.invalidEmail:
        return l10n.errorInvalidEmail;
      case AuthErrorCode.demoUnavailable:
        return l10n.errorDemoUnavailable;
    }
  }

  /// Resuelve cualquier excepcion tipada del dominio.
  ///
  /// Para excepciones no tipadas, devuelve [fallback].
  static String localize(AppLocalizations l10n, Object error, String fallback) {
    if (error is JoinEventException) return joinError(l10n, error);
    if (error is AudioRoomConfigurationException) {
      return audioError(l10n, error);
    }
    if (error is EventOperationException) {
      return operationError(l10n, error);
    }
    if (error is AppAuthException) return authError(l10n, error);
    return fallback;
  }
}
