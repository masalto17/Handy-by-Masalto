import 'dart:math';

import 'package:event_radio_app/src/shared/domain/app_exceptions.dart';

class InviteCodeGenerator {
  InviteCodeGenerator({Random? random}) : _random = random ?? Random.secure();

  static const _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  final Random _random;

  String generate({int length = 12}) {
    return List.generate(
      length,
      (_) => _alphabet[_random.nextInt(_alphabet.length)],
    ).join();
  }

  String generateUnique({
    required Set<String> existingCodes,
    int length = 12,
    int maxAttempts = 50,
  }) {
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final code = generate(length: length);
      if (!existingCodes.contains(code)) return code;
    }

    throw const EventOperationException(
      EventOperationErrorCode.codeGenerationFailed,
    );
  }
}
