import 'dart:async';

import 'package:event_radio_app/src/core/config/env_config.dart';
import 'package:event_radio_app/src/features/auth/domain/app_account.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final accountProvider =
    StateNotifierProvider<AccountController, AsyncValue<AppAccount?>>((ref) {
  if (EnvConfig.isSupabaseAvailable) {
    return SupabaseAccountController(Supabase.instance.client);
  }
  return MockAccountController();
});

abstract class AccountController
    extends StateNotifier<AsyncValue<AppAccount?>> {
  AccountController(super.state);

  Future<void> continueWithGoogle();

  Future<void> continueWithEmailLink(String email);

  Future<void> continueAsGuest();

  Future<void> continueAsLocalAdminDemo();

  /// [signOut] controla si se cierra la sesion de autenticacion por completo.
  /// Para participantes/invitados anonimos debe quedar en `false`: esa sesion
  /// anonima ES la identidad vinculada a su codigo de invitacion, y cerrarla
  /// invalidaria el codigo para siempre en este dispositivo.
  Future<void> clear({bool signOut = true});
}

class MockAccountController extends AccountController {
  MockAccountController() : super(const AsyncValue.data(null));

  @override
  Future<void> continueWithGoogle() async {
    state = const AsyncValue.loading();
    await Future<void>.delayed(const Duration(milliseconds: 250));
    state = const AsyncValue.data(
      AppAccount(
        id: 'mock-google-laura',
        displayName: 'Laura Sati',
        email: 'laura.sati@example.com',
        provider: 'google',
        isGuest: false,
      ),
    );
  }

  @override
  Future<void> continueWithEmailLink(String email) async {
    state = const AsyncValue.loading();
    await Future<void>.delayed(const Duration(milliseconds: 250));
    state = AsyncValue.data(
      AppAccount(
        id: 'mock-email-${email.trim().toLowerCase()}',
        displayName: email.trim().split('@').first,
        email: email.trim().toLowerCase(),
        provider: 'email',
        isGuest: false,
      ),
    );
  }

  @override
  Future<void> continueAsGuest() async {
    state = const AsyncValue.data(
      AppAccount(
        id: 'guest',
        displayName: 'Invitado',
        email: null,
        provider: 'guest',
        isGuest: true,
      ),
    );
  }

  @override
  Future<void> continueAsLocalAdminDemo() async {
    state = const AsyncValue.data(
      AppAccount(
        id: 'mock-admin',
        displayName: 'Coordinacion General',
        email: 'admin@event-radio.test',
        provider: 'email',
        isGuest: false,
      ),
    );
  }

  @override
  Future<void> clear({bool signOut = true}) async {
    state = const AsyncValue.data(null);
  }
}

class SupabaseAccountController extends AccountController {
  SupabaseAccountController(SupabaseClient client)
      : _client = client,
        super(AsyncValue.data(_accountFromUser(client.auth.currentUser))) {
    _authSubscription = _client.auth.onAuthStateChange.listen((event) {
      state = AsyncValue.data(_accountFromUser(event.session?.user));
    });
  }

  final SupabaseClient _client;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  Future<void> continueWithGoogle() async {
    state = const AsyncValue.loading();
    try {
      final started = await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: EnvConfig.authRedirectUrl,
      );
      if (!started) {
        state = const AsyncValue.error(
          'No pudimos iniciar Google.',
          StackTrace.empty,
        );
      }
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  @override
  Future<void> continueWithEmailLink(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) {
      state = const AsyncValue.error(
        'Ingresa un email valido.',
        StackTrace.empty,
      );
      return;
    }

    state = const AsyncValue.loading();
    try {
      await _client.auth.signInWithOtp(
        email: normalizedEmail,
        emailRedirectTo: EnvConfig.authRedirectUrl,
      );
      state = AsyncValue.data(
        AppAccount(
          id: 'email-link-pending',
          displayName: normalizedEmail,
          email: normalizedEmail,
          provider: 'email-link',
          isGuest: false,
        ),
      );
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  @override
  Future<void> continueAsGuest() async {
    state = const AsyncValue.loading();
    try {
      final response = await _client.auth.signInAnonymously();
      state = AsyncValue.data(_accountFromUser(response.user));
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  @override
  Future<void> continueAsLocalAdminDemo() async {
    // Gate en tiempo de compilacion: la credencial demo no debe existir en
    // un build de release salvo que DEMO este activado explicitamente.
    if (!EnvConfig.allowDemoShortcuts) {
      state = const AsyncValue.error(
        'El acceso demo no esta disponible en esta version.',
        StackTrace.empty,
      );
      return;
    }
    state = const AsyncValue.loading();
    try {
      await _client.auth.signOut();
      final response = await _client.auth.signInWithPassword(
        email: 'admin@event-radio.test',
        password: 'event-radio-admin',
      );
      state = AsyncValue.data(_accountFromUser(response.user));
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  @override
  Future<void> clear({bool signOut = true}) async {
    if (!signOut) {
      // Mantiene viva la sesion anonima para poder reingresar con el mismo
      // codigo de invitacion; solo se limpia el estado de cuenta en la UI.
      state = const AsyncValue.data(null);
      return;
    }
    state = const AsyncValue.loading();
    try {
      await _client.auth.signOut();
      state = const AsyncValue.data(null);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  static AppAccount? _accountFromUser(User? user) {
    if (user == null) return null;

    final metadata = user.userMetadata ?? const <String, dynamic>{};
    final appMetadata = user.appMetadata;
    final provider = user.email == null
        ? 'anonymous'
        : (appMetadata['provider'] as String?) ?? 'email';
    final displayName = (metadata['full_name'] as String?) ??
        (metadata['name'] as String?) ??
        user.email ??
        'Invitado';

    return AppAccount(
      id: user.id,
      displayName: displayName,
      email: user.email,
      provider: provider,
      isGuest: provider == 'anonymous' || user.email == null,
    );
  }
}
