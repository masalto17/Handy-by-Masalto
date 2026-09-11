import 'package:event_radio_app/l10n/app_localizations.dart';
import 'package:event_radio_app/src/core/theme/app_theme.dart';
import 'package:event_radio_app/src/shared/presentation/status_pill.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Helper que envuelve un widget en MaterialApp con localizaciones.
Widget _app(Widget child, {Locale locale = const Locale('en')}) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      ...GlobalMaterialLocalizations.delegates,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    locale: locale,
    theme: ThemeData.dark(),
    home: Scaffold(body: child),
  );
}

void main() {
  group('StatusPill accessibility', () {
    testWidgets('exposes label via Semantics', (tester) async {
      await tester.pumpWidget(_app(
        const StatusPill(
          label: 'ONGOING',
          color: AppTheme.success,
          icon: Icons.circle,
        ),
      ));

      // El Semantics wrapper debe exponer el label.
      final semantics = tester.getSemantics(find.byType(StatusPill));
      expect(semantics.label, 'ONGOING');
    });

    testWidgets('wraps content in ExcludeSemantics', (tester) async {
      await tester.pumpWidget(_app(
        const StatusPill(
          label: 'BLOCKED',
          color: AppTheme.warning,
          icon: Icons.lock,
        ),
      ));

      // El contenido visual (icon + text) esta dentro de ExcludeSemantics
      // para que el screen reader solo lea el Semantics label externo.
      // Flutter puede agregar ExcludeSemantics propios, por eso >= 1.
      expect(
        find.descendant(
          of: find.byType(StatusPill),
          matching: find.byType(ExcludeSemantics),
        ),
        findsAtLeastNWidgets(1),
      );
    });
  });

  group('PriorityBadge accessibility', () {
    testWidgets('critical badge uses i18n label', (tester) async {
      await tester.pumpWidget(_app(
        const PriorityBadge(isEmergency: true),
      ));

      // Debe mostrar la cadena i18n, no hardcoded "CRITICO".
      final semantics = tester.getSemantics(find.byType(PriorityBadge));
      expect(semantics.label, isNotEmpty);
      // En locale en, debe ser "CRITICAL".
      expect(semantics.label, 'CRITICAL');
    });

    testWidgets('operational badge uses i18n label', (tester) async {
      await tester.pumpWidget(_app(
        const PriorityBadge(isEmergency: false),
      ));

      final semantics = tester.getSemantics(find.byType(PriorityBadge));
      expect(semantics.label, 'OPERATIONAL');
    });

    testWidgets('badge label changes with locale', (tester) async {
      await tester.pumpWidget(
        _app(
          const PriorityBadge(isEmergency: true),
          locale: const Locale('es'),
        ),
      );

      final semantics = tester.getSemantics(find.byType(PriorityBadge));
      expect(semantics.label, 'CRITICO');
    });
  });
}
