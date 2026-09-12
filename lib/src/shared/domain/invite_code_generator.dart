import 'dart:math';

import 'package:event_radio_app/src/shared/domain/app_exceptions.dart';

/// Genera codigos de invitacion alfanumericos con caracteres no ambiguos.
///
/// Excluye `0`, `O`, `1`, `I` para evitar confusiones en lectura manual.
/// Usa [Random.secure] por defecto para garantizar imprevisibilidad.
class InviteCodeGenerator {
  /// Crea un generador con la fuente de aleatoriedad dada (o [Random.secure]).
  InviteCodeGenerator({Random? random}) : _random = random ?? Random.secure();

  /// Alfabeto sin caracteres ambiguos (sin 0, O, 1, I).
  static const _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  final Random _random;

  /// Genera un codigo aleatorio de [length] caracteres.
  String generate({int length = 12}) {
    return List.generate(
      length,
      (_) => _alphabet[_random.nextInt(_alphabet.length)],
    ).join();
  }

  /// Genera un codigo unico que no exista en [existingCodes].
  ///
  /// Reintenta hasta [maxAttempts] veces. Lanza
  /// [EventOperationException] con [EventOperationErrorCode.codeGenerationFailed]
  /// si no logra generar uno unico.
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
