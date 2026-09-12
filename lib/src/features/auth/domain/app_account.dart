/// Modelo de cuenta de usuario autenticado.
///
/// Representa la identidad con la que el usuario opera dentro de la app,
/// independientemente del proveedor de autenticacion (Google, email, anonimo).
/// Para invitados anonimos, [email] es `null` e [isGuest] es `true`.
class AppAccount {
  /// Crea una cuenta con todos los campos requeridos.
  const AppAccount({
    required this.id,
    required this.displayName,
    required this.email,
    required this.provider,
    required this.isGuest,
  });

  /// Identificador unico del usuario (UUID de Supabase o mock ID).
  final String id;

  /// Nombre visible en la UI (nombre completo o email como fallback).
  final String displayName;

  /// Email del usuario; `null` para sesiones anonimas.
  final String? email;

  /// Proveedor de autenticacion: `'google'`, `'email'`, `'anonymous'`, etc.
  final String provider;

  /// `true` si la sesion es anonima o no tiene email vinculado.
  final bool isGuest;
}
