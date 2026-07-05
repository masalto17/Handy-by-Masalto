class InviteCodeParser {
  const InviteCodeParser._();

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
