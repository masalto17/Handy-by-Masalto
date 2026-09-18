import 'package:event_radio_app/l10n/app_localizations.dart';
import 'package:event_radio_app/src/features/channel/presentation/sos_hold_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  const holdDuration = Duration(milliseconds: 1200);

  testWidgets('a plain tap does NOT fire the SOS', (tester) async {
    var fired = 0;
    await tester.pumpWidget(_wrap(
      SosHoldButton(
        enabled: true,
        isSending: false,
        holdDuration: holdDuration,
        onActivate: () => fired++,
      ),
    ));

    await tester.tap(find.byType(SosHoldButton));
    await tester.pumpAndSettle();

    // Es la razon de ser del gesto sostenido: el boton vive bajo el pulgar,
    // un roce no puede disparar una emergencia.
    expect(fired, 0);
  });

  testWidgets('releasing before the hold completes cancels it', (tester) async {
    var fired = 0;
    await tester.pumpWidget(_wrap(
      SosHoldButton(
        enabled: true,
        isSending: false,
        holdDuration: holdDuration,
        onActivate: () => fired++,
      ),
    ));

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(SosHoldButton)),
    );
    await tester.pump(const Duration(milliseconds: 700));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(fired, 0);
  });

  testWidgets('holding past the duration fires once', (tester) async {
    var fired = 0;
    await tester.pumpWidget(_wrap(
      SosHoldButton(
        enabled: true,
        isSending: false,
        holdDuration: holdDuration,
        onActivate: () => fired++,
      ),
    ));

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(SosHoldButton)),
    );
    await tester.pump(const Duration(milliseconds: 1400));
    // Seguir apretando despues de disparar no debe repetir el envio.
    await tester.pump(const Duration(milliseconds: 1400));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(fired, 1);
  });

  testWidgets('does not fire while disabled', (tester) async {
    var fired = 0;
    await tester.pumpWidget(_wrap(
      SosHoldButton(
        enabled: false,
        isSending: false,
        holdDuration: holdDuration,
        onActivate: () => fired++,
      ),
    ));

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(SosHoldButton)),
    );
    await tester.pump(const Duration(milliseconds: 1400));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(fired, 0);
    expect(find.text('SOS blocked'), findsOneWidget);
  });

  testWidgets('does not fire while a previous SOS is still sending',
      (tester) async {
    var fired = 0;
    await tester.pumpWidget(_wrap(
      SosHoldButton(
        enabled: true,
        isSending: true,
        holdDuration: holdDuration,
        onActivate: () => fired++,
      ),
    ));

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(SosHoldButton)),
    );
    await tester.pump(const Duration(milliseconds: 1400));
    await gesture.up();
    // pump y no pumpAndSettle: con isSending el spinner gira indefinidamente
    // y pumpAndSettle nunca terminaria.
    await tester.pump(const Duration(milliseconds: 100));

    expect(fired, 0);
  });
}
