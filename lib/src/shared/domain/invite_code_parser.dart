/// Extrae un codigo de invitacion limpio a partir de distintos formatos
/// de entrada: URL con query parameter `code`, URL con el codigo como
/// ultimo segmento de path, o texto plano.
///
/// Todos los resultados se devuelven en mayusculas y sin espacios.
class InviteCodeParser {
  const InviteCodeParser._();

  /// Parsea [value] (texto de QR, deep link, o entrada manual) y devuelve
  /// el codigo normalizado en mayusculas.
  ///
  /// Prioridad: `?code=XXX` > ultimo segmento de path > texto tal cual.
  /// Devuelve cadena vacia si [value] esta vacio.
  static String fromQrValue(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';

    final uri = Uri.tryParse(trimmed);
    final queryCode = uri?.queryParameters['code'];
    if (queryCode != null && queryCode.trim().isNotEmpty) {
      return queryCode.trim().toUpperCase();
    }

    if (uri != null &&
        uri.scheme.isNotEmpty &&
        uri.pathSegments.isNotEmpty &&
        uri.pathSegments.last.trim().isNotEmpty) {
      return uri.pathSegments.last.trim().toUpperCase();
    }

    return trimmed.toUpperCase();
  }

  /// Normaliza un codigo tipeado a mano por el operador.
  ///
  /// La gente copia los codigos desde un papel, un chat o una credencial, y
  /// los escribe con separadores ("SATI-26", "sati 26"). Esta funcion deja
  /// solo caracteres alfanumericos en mayusculas para que esas variantes
  /// ingresen igual.
  ///
  /// Deliberadamente NO corrige caracteres ambiguos (`0`/`O`, `1`/`I`): los
  /// codigos generados por [InviteCodeGenerator] los excluyen, pero un admin
  /// puede fijar un codigo manual que si los use, y adivinar cambiaria un
  /// codigo valido por uno inexistente.
  static String normalizeManualEntry(String value) {
    return value.replaceAll(RegExp('[^a-zA-Z0-9]'), '').toUpperCase();
  }
}
