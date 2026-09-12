import 'package:event_radio_app/src/features/admin/presentation/admin_helpers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('inviteUri', () {
    test('generates deep link from invite code', () {
      expect(inviteUri('ABC123'), 'event-radio://join?code=ABC123');
    });

    test('generated URI has parseable scheme, host, and code', () {
      final uri = Uri.parse(inviteUri('SATI26'));
      expect(uri.scheme, 'event-radio');
      expect(uri.host, 'join');
      expect(uri.queryParameters['code'], 'SATI26');
    });
  });

  group('normalizeChannelCode', () {
    test('lowercases and replaces non-alphanumeric with hyphens', () {
      expect(normalizeChannelCode('  Canal Uno!  '), 'canal-uno');
    });

    test('strips leading and trailing hyphens', () {
      expect(normalizeChannelCode('---foo---'), 'foo');
    });

    test('collapses consecutive special chars into single hyphen', () {
      expect(normalizeChannelCode('a   b___c'), 'a-b-c');
    });

    test('returns empty for whitespace-only input', () {
      expect(normalizeChannelCode('   '), '');
    });
  });

  group('normalizeInviteCode', () {
    test('uppercases and strips non-alphanumeric', () {
      expect(normalizeInviteCode('  abc-123  '), 'ABC123');
    });

    test('returns empty for punctuation-only input', () {
      expect(normalizeInviteCode('---'), '');
    });
  });
}
