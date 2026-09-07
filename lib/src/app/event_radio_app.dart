import 'package:event_radio_app/l10n/app_localizations.dart';
import 'package:event_radio_app/src/app/router.dart';
import 'package:event_radio_app/src/core/config/app_bootstrap.dart';
import 'package:event_radio_app/src/core/theme/app_theme.dart';
import 'package:event_radio_app/src/shared/presentation/bootstrap_error_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class EventRadioApp extends ConsumerWidget {
  const EventRadioApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final error = AppBootstrap.initError;

    // Si la inicializacion fallo en un build que no admite modo demo,
    // mostrar pantalla de error en lugar de operar sobre datos mock.
    if (error != null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BootstrapErrorScreen(error: error),
      );
    }

    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
