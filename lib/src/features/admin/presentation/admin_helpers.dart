import 'package:event_radio_app/src/shared/domain/event_models.dart';
import 'package:event_radio_app/src/shared/domain/invite_code_generator.dart';
import 'package:flutter/material.dart';

/// URI de invitacion generada a partir del codigo.
String inviteUri(String inviteCode) => 'event-radio://join?code=$inviteCode';

/// Normaliza un codigo de canal: minusculas, alfanumerico con guiones.
String normalizeChannelCode(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
}

/// Normaliza un codigo de invitacion: mayusculas, solo alfanumerico.
String normalizeInviteCode(String value) {
  return value.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]+'), '');
}

/// Genera un codigo de invitacion unico dentro de la sesion.
String generateUniqueInviteCode(
  EventSession session, {
  String? exceptParticipantId,
}) {
  final existingCodes = session.participants
      .where((participant) => participant.id != exceptParticipantId)
      .map((participant) => participant.inviteCode)
      .toSet();
  return InviteCodeGenerator().generateUnique(existingCodes: existingCodes);
}

/// Muestra un error de validacion en un SnackBar.
void showAdminError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}
