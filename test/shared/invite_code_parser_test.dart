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
}
