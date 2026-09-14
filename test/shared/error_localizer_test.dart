import 'package:event_radio_app/l10n/app_localizations.dart';
import 'package:event_radio_app/src/shared/audio/audio_room_service.dart';
import 'package:event_radio_app/src/shared/domain/app_exceptions.dart';
import 'package:event_radio_app/src/shared/domain/event_radio_repository.dart';
import 'package:event_radio_app/src/shared/presentation/error_localizer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps a minimal app with localization so we can obtain [AppLocalizations].
Future<AppLocalizations> _pumpL10n(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
}) async {
  late AppLocalizations l10n;
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      home: Builder(
        builder: (context) {
          l10n = AppLocalizations.of(context);
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return l10n;
}

void main() {
  group('ErrorLocalizer.joinError', () {
    testWidgets('maps emptyCode to i18n string', (tester) async {
      final l10n = await _pumpL10n(tester);
      const error = JoinEventException(JoinErrorCode.emptyCode);
      expect(ErrorLocalizer.joinError(l10n, error), l10n.errorEmptyCode);
    });

    testWidgets('maps codeNotFound to i18n string', (tester) async {
      final l10n = await _pumpL10n(tester);
      const error = JoinEventException(JoinErrorCode.codeNotFound);
      expect(ErrorLocalizer.joinError(l10n, error), l10n.errorCodeNotFound);
    });

    testWidgets('maps sessionExpired to i18n string', (tester) async {
      final l10n = await _pumpL10n(tester);
      const error = JoinEventException(JoinErrorCode.sessionExpired);
      expect(ErrorLocalizer.joinError(l10n, error), l10n.errorSessionExpired);
    });

    testWidgets('maps authRequired to i18n string', (tester) async {
      final l10n = await _pumpL10n(tester);
      const error = JoinEventException(JoinErrorCode.authRequired);
      expect(ErrorLocalizer.joinError(l10n, error), l10n.errorAuthRequired);
    });

    testWidgets('maps inviteFailed with serverMessage', (tester) async {
      final l10n = await _pumpL10n(tester);
      const error = JoinEventException(
        JoinErrorCode.inviteFailed,
        serverMessage: 'Server says no',
      );
      expect(ErrorLocalizer.joinError(l10n, error), 'Server says no');
    });

    testWidgets('maps inviteFailed without serverMessage to i18n',
        (tester) async {
      final l10n = await _pumpL10n(tester);
      const error = JoinEventException(JoinErrorCode.inviteFailed);
      expect(ErrorLocalizer.joinError(l10n, error), l10n.errorInviteFailed);
    });

    testWidgets('maps unknown with serverMessage', (tester) async {
      final l10n = await _pumpL10n(tester);
      const error = JoinEventException(
        JoinErrorCode.unknown,
        serverMessage: 'Algo salio mal',
      );
      expect(ErrorLocalizer.joinError(l10n, error), 'Algo salio mal');
    });

    testWidgets('maps unknown without serverMessage to generic i18n',
        (tester) async {
      final l10n = await _pumpL10n(tester);
      const error = JoinEventException(JoinErrorCode.unknown);
      expect(ErrorLocalizer.joinError(l10n, error), l10n.joinError);
    });

    testWidgets('Spanish locale returns Spanish strings', (tester) async {
      final l10n = await _pumpL10n(tester, locale: const Locale('es'));
      const error = JoinEventException(JoinErrorCode.emptyCode);
      expect(
        ErrorLocalizer.joinError(l10n, error),
        'El codigo esta vacio.',
      );
    });
  });

  group('ErrorLocalizer.audioError', () {
    testWidgets('maps microphoneDenied', (tester) async {
      final l10n = await _pumpL10n(tester);
      const error = AudioRoomConfigurationException(
        AudioRoomErrorCode.microphoneDenied,
      );
      expect(
        ErrorLocalizer.audioError(l10n, error),
        l10n.errorMicrophoneDenied,
      );
    });

    testWidgets('maps tokenFetchFailed with serverMessage', (tester) async {
      final l10n = await _pumpL10n(tester);
      const error = AudioRoomConfigurationException(
        AudioRoomErrorCode.tokenFetchFailed,
        serverMessage: 'Token expired',
      );
      expect(ErrorLocalizer.audioError(l10n, error), 'Token expired');
    });

    testWidgets('maps invalidTokenResponse', (tester) async {
      final l10n = await _pumpL10n(tester);
      const error = AudioRoomConfigurationException(
        AudioRoomErrorCode.invalidTokenResponse,
      );
      expect(
        ErrorLocalizer.audioError(l10n, error),
        l10n.errorInvalidTokenResponse,
      );
    });

    testWidgets('maps pttStartFailed', (tester) async {
      final l10n = await _pumpL10n(tester);
      const error = AudioRoomConfigurationException(
        AudioRoomErrorCode.pttStartFailed,
      );
      expect(ErrorLocalizer.audioError(l10n, error), l10n.pttAudioStartError);
    });
  });

  group('ErrorLocalizer.operationError', () {
    testWidgets('maps eventNotOperational', (tester) async {
      final l10n = await _pumpL10n(tester);
      const error = EventOperationException(
        EventOperationErrorCode.eventNotOperational,
      );
      expect(
        ErrorLocalizer.operationError(l10n, error),
        l10n.errorEventNotOperational,
      );
    });

    testWidgets('maps insufficientPermission', (tester) async {
      final l10n = await _pumpL10n(tester);
      const error = EventOperationException(
        EventOperationErrorCode.insufficientPermission,
      );
      expect(
        ErrorLocalizer.operationError(l10n, error),
        l10n.errorInsufficientPermission,
      );
    });

    testWidgets('maps transcriptionFailed with serverMessage', (tester) async {
      final l10n = await _pumpL10n(tester);
      const error = EventOperationException(
        EventOperationErrorCode.transcriptionFailed,
        serverMessage: 'Whisper quota exceeded',
      );
      expect(
        ErrorLocalizer.operationError(l10n, error),
        'Whisper quota exceeded',
      );
    });
  });

  group('ErrorLocalizer.authError', () {
    testWidgets('maps googleSignInFailed', (tester) async {
      final l10n = await _pumpL10n(tester);
      const error = AppAuthException(AuthErrorCode.googleSignInFailed);
      expect(
        ErrorLocalizer.authError(l10n, error),
        l10n.errorGoogleSignInFailed,
      );
    });

    testWidgets('maps invalidEmail', (tester) async {
      final l10n = await _pumpL10n(tester);
      const error = AppAuthException(AuthErrorCode.invalidEmail);
      expect(ErrorLocalizer.authError(l10n, error), l10n.errorInvalidEmail);
    });

    testWidgets('maps demoUnavailable', (tester) async {
      final l10n = await _pumpL10n(tester);
      const error = AppAuthException(AuthErrorCode.demoUnavailable);
      expect(
        ErrorLocalizer.authError(l10n, error),
        l10n.errorDemoUnavailable,
      );
    });
  });

  group('ErrorLocalizer.localize', () {
    testWidgets('resolves JoinEventException', (tester) async {
      final l10n = await _pumpL10n(tester);
      const error = JoinEventException(JoinErrorCode.emptyCode);
      expect(
        ErrorLocalizer.localize(l10n, error, 'fallback'),
        l10n.errorEmptyCode,
      );
    });

    testWidgets('resolves AudioRoomConfigurationException', (tester) async {
      final l10n = await _pumpL10n(tester);
      const error = AudioRoomConfigurationException(
        AudioRoomErrorCode.microphoneDenied,
      );
      expect(
        ErrorLocalizer.localize(l10n, error, 'fallback'),
        l10n.errorMicrophoneDenied,
      );
    });

    testWidgets('resolves EventOperationException', (tester) async {
      final l10n = await _pumpL10n(tester);
      const error = EventOperationException(
        EventOperationErrorCode.eventNotOperational,
      );
      expect(
        ErrorLocalizer.localize(l10n, error, 'fallback'),
        l10n.errorEventNotOperational,
      );
    });

    testWidgets('resolves AppAuthException', (tester) async {
      final l10n = await _pumpL10n(tester);
      const error = AppAuthException(AuthErrorCode.googleSignInFailed);
      expect(
        ErrorLocalizer.localize(l10n, error, 'fallback'),
        l10n.errorGoogleSignInFailed,
      );
    });

    testWidgets('returns fallback for unknown exception type', (tester) async {
      final l10n = await _pumpL10n(tester);
      expect(
        ErrorLocalizer.localize(l10n, StateError('x'), 'fallback'),
        'fallback',
      );
    });
  });
}
