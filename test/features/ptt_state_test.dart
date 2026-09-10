import 'package:event_radio_app/src/features/channel/domain/ptt_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PttPhase', () {
    test('idle is the default', () {
      const state = PttState();
      expect(state.phase, PttPhase.idle);
      expect(state.isIdle, isTrue);
    });

    test('requesting phase flags', () {
      const state = PttState(phase: PttPhase.requesting);
      expect(state.isRequesting, isTrue);
      expect(state.isActive, isTrue);
      expect(state.isBusy, isTrue);
      expect(state.isIdle, isFalse);
      expect(state.isTransmitting, isFalse);
    });

    test('transmitting phase flags', () {
      const state = PttState(phase: PttPhase.transmitting);
      expect(state.isTransmitting, isTrue);
      expect(state.isActive, isTrue);
      expect(state.isBusy, isTrue);
      expect(state.isIdle, isFalse);
    });

    test('finalizing phase flags', () {
      const state = PttState(phase: PttPhase.finalizing);
      expect(state.isFinalizing, isTrue);
      expect(state.isBusy, isTrue);
      expect(state.isActive, isFalse);
    });

    test('error phase flags', () {
      const state = PttState(
        phase: PttPhase.error,
        errorMessage: 'Permiso denegado',
      );
      expect(state.isError, isTrue);
      expect(state.isBusy, isFalse, reason: 'error allows new press');
      expect(state.isActive, isFalse);
      expect(state.errorMessage, 'Permiso denegado');
    });
  });

  group('PttState.idle constant', () {
    test('is idle with zero elapsed and no error', () {
      expect(PttState.idle.isIdle, isTrue);
      expect(PttState.idle.elapsedSeconds, 0);
      expect(PttState.idle.errorMessage, isNull);
    });
  });

  group('copyWith', () {
    test('preserves phase and updates elapsed', () {
      const state = PttState(phase: PttPhase.transmitting, elapsedSeconds: 5);
      final updated = state.copyWith(elapsedSeconds: 10);
      expect(updated.phase, PttPhase.transmitting);
      expect(updated.elapsedSeconds, 10);
    });

    test('transitions phase', () {
      const state = PttState(phase: PttPhase.requesting);
      final updated = state.copyWith(phase: PttPhase.transmitting);
      expect(updated.isTransmitting, isTrue);
      expect(updated.isRequesting, isFalse);
    });

    test('clears errorMessage when not passed', () {
      const state = PttState(
        phase: PttPhase.error,
        errorMessage: 'Error previo',
      );
      final updated = state.copyWith(phase: PttPhase.idle);
      expect(updated.errorMessage, isNull,
          reason: 'errorMessage uses named param default (null)');
    });
  });

  group('isBusy prevents new press', () {
    test('idle allows press', () {
      expect(PttState.idle.isBusy, isFalse);
    });

    test('error allows press', () {
      const state = PttState(phase: PttPhase.error);
      expect(state.isBusy, isFalse);
    });

    test('requesting blocks press', () {
      const state = PttState(phase: PttPhase.requesting);
      expect(state.isBusy, isTrue);
    });

    test('transmitting blocks press', () {
      const state = PttState(phase: PttPhase.transmitting);
      expect(state.isBusy, isTrue);
    });

    test('finalizing blocks press', () {
      const state = PttState(phase: PttPhase.finalizing);
      expect(state.isBusy, isTrue);
    });
  });
}
