import 'package:flutter/services.dart';

/// Convierte a mayusculas lo que el operador escribe, en vivo.
///
/// Los codigos de invitacion siempre se validan en mayusculas. Transformar
/// mientras se tipea evita que el operador vea un texto distinto al que se
/// envia, y conserva la posicion del cursor para no romper la edicion.
class UpperCaseTextFormatter extends TextInputFormatter {
  /// Crea el formateador.
  const UpperCaseTextFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final upper = newValue.text.toUpperCase();
    if (upper == newValue.text) return newValue;
    // El largo no cambia al pasar a mayusculas, asi que la seleccion original
    // sigue siendo valida.
    return newValue.copyWith(text: upper);
  }
}
