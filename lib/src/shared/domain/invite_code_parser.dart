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
}
