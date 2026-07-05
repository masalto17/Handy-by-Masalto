import 'package:event_radio_app/src/shared/domain/invite_code_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('generates long uppercase invite codes without ambiguous characters',
      () {
    final generator = InviteCodeGenerator();

    final code = generator.generate();

    expect(code, hasLength(12));
    expect(code, matches(RegExp(r'^[A-HJ-NP-Z2-9]+$')));
  });

  test('generates a code that does not collide with existing codes', () {
    final generator = InviteCodeGenerator();
    final existingCodes = <String>{
      for (var i = 0; i < 200; i++) generator.generate(),
    };

    final code = generator.generateUnique(existingCodes: existingCodes);

    expect(existingCodes, isNot(contains(code)));
    expect(code, hasLength(12));
  });
}
