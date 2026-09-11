import 'package:event_radio_app/src/shared/data/event_radio_providers.dart';
import 'package:event_radio_app/src/shared/data/mock_event_radio_repository.dart';
import 'package:event_radio_app/src/shared/domain/app_exceptions.dart';
import 'package:event_radio_app/src/shared/domain/event_models.dart';
import 'package:event_radio_app/src/shared/domain/event_radio_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Un repositorio que falla en las operaciones de mutacion para verificar
/// que el controller preserva el estado anterior.
class _FailingRepository extends MockEventRadioRepository {
  @override
  Future<EventSession> updateEventDetails({
    required EventSession session,
    required String name,
    required String description,
    required EventStatus status,
    required DateTime startsAt,
    required DateTime endsAt,
  }) async {
    throw Exception('updateEventDetails failed');
  }

  @override
  Future<EventSession> createChannel({
    required EventSession session,
    required String name,
    required String code,
    required String description,
    required int priority,
    required bool isEmergency,
  }) async {
    throw Exception('createChannel failed');
  }

  @override
  Future<EventSession> deleteChannel({
    required EventSession session,
    required EventChannel channel,
  }) async {
    throw Exception('deleteChannel failed');
  }

  @override
  Future<EventSession> createParticipant({
    required EventSession session,
    required String displayName,
    required String phone,
    required ParticipantRole role,
    required String inviteCode,
  }) async {
    throw Exception('createParticipant failed');
  }

  @override
  Future<EventSession> deleteParticipant({
    required EventSession session,
    required EventParticipant participant,
  }) async {
    throw Exception('deleteParticipant failed');
  }

  @override
  Future<EventSession> updateParticipantChannels({
    required EventSession session,
    required EventParticipant participant,
    required List<ChannelPermission> permissions,
  }) async {
    throw Exception('updateParticipantChannels failed');
  }
}

void main() {
  late CurrentSessionController controller;
  late EventSession session;

  setUp(() async {
    // Primero creamos una sesion valida via mock y luego la inyectamos al
    // controller que falla, para poder probar la preservacion de estado.
    final mockController = CurrentSessionController(MockEventRadioRepository());
    session = await mockController.joinByCode('SATI26');

    controller = CurrentSessionController(_FailingRepository());
    // Inyectamos la sesion como estado actual.
    controller.state = AsyncValue.data(session);
  });

  group('CurrentSessionController preserves state on error', () {
    test('updateEventDetails preserves state', () async {
      final before = controller.state;
      await expectLater(
        () => controller.updateEventDetails(
          session: session,
          name: 'New name',
          description: '',
          status: EventStatus.active,
          startsAt: DateTime.now(),
          endsAt: DateTime.now().add(const Duration(hours: 2)),
        ),
        throwsA(isA<Exception>()),
      );
      expect(controller.state, before);
    });

    test('createChannel preserves state', () async {
      final before = controller.state;
      await expectLater(
        () => controller.createChannel(
          session: session,
          name: 'Test',
          code: 'TST',
          description: '',
          priority: 0,
          isEmergency: false,
        ),
        throwsA(isA<Exception>()),
      );
      expect(controller.state, before);
    });

    test('deleteChannel preserves state', () async {
      final before = controller.state;
      await expectLater(
        () => controller.deleteChannel(
          session: session,
          channel: session.channels.first,
        ),
        throwsA(isA<Exception>()),
      );
      expect(controller.state, before);
    });

    test('createParticipant preserves state', () async {
      final before = controller.state;
      await expectLater(
        () => controller.createParticipant(
          session: session,
          displayName: 'Test',
          phone: '',
          role: ParticipantRole.coordinator,
          inviteCode: 'TEST-123',
        ),
        throwsA(isA<Exception>()),
      );
      expect(controller.state, before);
    });

    test('deleteParticipant preserves state', () async {
      final before = controller.state;
      await expectLater(
        () => controller.deleteParticipant(
          session: session,
          participant: session.participants.first,
        ),
        throwsA(isA<Exception>()),
      );
      expect(controller.state, before);
    });

    test('updateParticipantChannels preserves state', () async {
      final before = controller.state;
      await expectLater(
        () => controller.updateParticipantChannels(
          session: session,
          participant: session.participants.first,
          permissions: [],
        ),
        throwsA(isA<Exception>()),
      );
      expect(controller.state, before);
    });
  });

  group('AppAuthException', () {
    test('toString returns code name by default', () {
      const error = AppAuthException(AuthErrorCode.googleSignInFailed);
      expect(error.toString(), 'googleSignInFailed');
    });

    test('toString returns serverMessage when provided', () {
      const error = AppAuthException(
        AuthErrorCode.googleSignInFailed,
        serverMessage: 'Custom error',
      );
      expect(error.toString(), 'Custom error');
    });
  });
}
