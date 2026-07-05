import 'package:event_radio_app/src/shared/domain/event_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('EventStatus parses known and unknown values', () {
    expect(EventStatus.fromValue('active'), EventStatus.active);
    expect(EventStatus.fromValue('unknown'), EventStatus.draft);
  });

  test('ParticipantRole parses coordinator role', () {
    expect(
      ParticipantRole.fromValue('coordinator'),
      ParticipantRole.coordinator,
    );
  });

  test('TranscriptionStatus parses known and unknown values', () {
    expect(TranscriptionStatus.fromValue('queued'), TranscriptionStatus.queued);
    expect(
        TranscriptionStatus.fromValue('unknown'), TranscriptionStatus.pending);
  });

  test('event is operational only while active and inside schedule', () {
    final now = DateTime(2026, 6, 23, 12);
    final event = EventRadioEvent(
      id: 'event-1',
      name: 'Evento',
      startsAt: now.subtract(const Duration(hours: 1)),
      endsAt: now.add(const Duration(hours: 1)),
      status: EventStatus.active,
    );

    expect(event.isOperational(now), isTrue);
    expect(event.isOperational(now.add(const Duration(hours: 2))), isFalse);
  });

  test('VoiceMessage reads storage and transcription contract fields', () {
    final message = VoiceMessage.fromMap({
      'id': 'message-1',
      'event_id': 'event-1',
      'channel_id': 'channel-1',
      'participant_id': 'participant-1',
      'event_participants': {'display_name': 'Laura'},
      'storage_path': 'event-1/channel-1/message-1.webm',
      'duration_seconds': 3,
      'transcription_text': 'Audio transcripto.',
      'transcription_status': 'completed',
      'transcription_provider': 'mock',
      'transcription_job_id': 'job-1',
      'is_priority': false,
      'created_at': '2026-06-23T15:00:00Z',
    });

    expect(message.senderName, 'Laura');
    expect(message.storagePath, 'event-1/channel-1/message-1.webm');
    expect(message.hasAudio, isTrue);
    expect(message.transcriptionText, 'Audio transcripto.');
    expect(message.transcription, 'Audio transcripto.');
    expect(message.transcriptionStatus, TranscriptionStatus.completed);
    expect(message.transcriptionProvider, 'mock');
    expect(message.transcriptionJobId, 'job-1');
    expect(message.isTranscriptionFinal, isTrue);
  });

  test('VoiceMessage keeps legacy transcription fallback', () {
    final message = VoiceMessage.fromMap({
      'id': 'message-1',
      'event_id': 'event-1',
      'channel_id': 'channel-1',
      'participant_id': 'participant-1',
      'transcription': 'Texto legacy.',
      'transcription_status': 'completed',
      'created_at': '2026-06-23T15:00:00Z',
    });

    expect(message.transcriptionText, 'Texto legacy.');
    expect(message.transcription, 'Texto legacy.');
  });
}
