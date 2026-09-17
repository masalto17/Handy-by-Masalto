import 'package:event_radio_app/src/shared/domain/invite_code_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses direct invite codes', () {
    expect(InviteCodeParser.fromQrValue(' sati26 '), 'SATI26');
  });

  test('parses invite code from query parameter', () {
    expect(
      InviteCodeParser.fromQrValue('event-radio://join?code=sati26'),
      'SATI26',
    );
  });

  test('parses invite code from url path segment', () {
    expect(
      InviteCodeParser.fromQrValue('https://event.radio/join/cerrado'),
      'CERRADO',
    );
  });

  group('normalizeManualEntry', () {
    test('uppercases and strips spaces', () {
      expect(InviteCodeParser.normalizeManualEntry(' sati 26 '), 'SATI26');
    });

    test('strips separators people copy from printed codes', () {
      expect(InviteCodeParser.normalizeManualEntry('SATI-26'), 'SATI26');
      expect(InviteCodeParser.normalizeManualEntry('SATI.26'), 'SATI26');
      expect(InviteCodeParser.normalizeManualEntry('SATI_26'), 'SATI26');
    });

    test('keeps ambiguous characters untouched', () {
      // Un admin puede fijar un codigo manual con 0/O/1/I: corregirlos
      // convertiria un codigo valido en uno inexistente.
      expect(
        InviteCodeParser.normalizeManualEntry('PILOTOADMIN123'),
        'PILOTOADMIN123',
      );
      expect(InviteCodeParser.normalizeManualEntry('0O1I'), '0O1I');
    });

    test('returns empty string for input without alphanumerics', () {
      expect(InviteCodeParser.normalizeManualEntry('  --  '), '');
    });
  });
}
