import 'package:event_radio_app/src/app/event_radio_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('join flow opens active event and channel screen',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: EventRadioApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Join an event'), findsOneWidget);
    expect(find.text('MODO MOCK - datos locales para demo'), findsOneWidget);
    await _tapVisible(tester, find.text('Join'));
    await tester.pumpAndSettle();

    expect(find.text('CONGRESO OPERACIONES SATI-26'), findsOneWidget);
    expect(find.text('Seguridad interna'), findsOneWidget);

    await tester.tap(find.text('Seguridad interna'));
    await tester.pumpAndSettle();

    expect(find.text('PUSH-TO-TALK'), findsOneWidget);
    expect(find.text('HOLD TO TALK'), findsOneWidget);
  });

  testWidgets('invalid code shows validation message', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: EventRadioApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'MAL');
    await _tapVisible(tester, find.text('Join'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Codigo no encontrado'), findsOneWidget);
  });

  testWidgets('mock account can be selected before joining', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: EventRadioApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Optional account'), findsOneWidget);

    await tester.tap(find.text('Continue with Gmail'));
    await tester.pumpAndSettle();

    expect(find.text('Laura Sati'), findsOneWidget);
    expect(find.textContaining('laura.sati@example.com'), findsOneWidget);

    await _tapVisible(tester, find.text('Join'));
    await tester.pumpAndSettle();

    expect(find.text('CONGRESO OPERACIONES SATI-26'), findsOneWidget);
  });

  testWidgets('qr demo flow opens active event', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: EventRadioApp(),
      ),
    );
    await tester.pumpAndSettle();

    await _tapVisible(tester, find.text('Scan QR'));
    await tester.pumpAndSettle();

    expect(find.text('Point at the event QR'), findsOneWidget);

    await tester.tap(find.text('Try demo QR SATI26'));
    await tester.pumpAndSettle();

    expect(find.text('CONGRESO OPERACIONES SATI-26'), findsOneWidget);
  });

  testWidgets('closed event keeps channel history visible and blocks PTT',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: EventRadioApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'CERRADO');
    await _tapVisible(tester, find.text('Join'));
    await tester.pumpAndSettle();

    expect(find.text('TRANSMISSION BLOCKED'), findsOneWidget);

    await tester.tap(find.text('View channels and history'));
    await tester.pumpAndSettle();

    expect(find.text('Channels and history'), findsOneWidget);
    expect(find.text('Produccion'), findsOneWidget);
    expect(find.textContaining('PTT blocked'), findsOneWidget);

    await tester.tap(find.text('Produccion'));
    await tester.pumpAndSettle();

    expect(find.text('PUSH-TO-TALK'), findsOneWidget);
    expect(find.text('TRANSMISSION BLOCKED'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('History'), 500);
    await tester.pumpAndSettle();
    expect(find.text('History'), findsOneWidget);
    expect(find.text('SOS blocked'), findsOneWidget);
  });

  testWidgets('ptt gesture saves simulated message', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: EventRadioApp(),
      ),
    );
    await tester.pumpAndSettle();

    await _tapVisible(tester, find.text('Join'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Produccion'));
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('ptt-button'))),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('TRANSMITTING'), findsOneWidget);

    await gesture.up();
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -350));
    await tester.pumpAndSettle();
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Coordinacion confirma avance'),
      findsOneWidget,
    );
  });

  testWidgets('sos button saves priority message in history', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: EventRadioApp(),
      ),
    );
    await tester.pumpAndSettle();

    await _tapVisible(tester, find.text('Join'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Seguridad interna'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('SOS'), 250);
    await tester.tap(find.text('SOS'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('SOS activated in Seguridad interna'),
      findsWidgets,
    );

    await _tapVisible(tester, find.text('History'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('SOS activated in Seguridad interna'),
      findsWidgets,
    );
    expect(find.byIcon(Icons.priority_high), findsWidgets);
  });

  testWidgets('admin mock edits event and adds channel and participant',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: EventRadioApp(),
      ),
    );
    await tester.pumpAndSettle();

    await _tapVisible(tester, find.text('Join'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Activity log'));
    await tester.pumpAndSettle();

    expect(find.text('Event'), findsOneWidget);
    expect(find.text('Startup checklist'), findsOneWidget);
    expect(find.text('READY FOR TEST'), findsOneWidget);

    await tester.tap(find.byTooltip('Edit event'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Operativo admin');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Operativo admin'), findsOneWidget);

    final createChannelButton = find.byTooltip('Create channel');
    await tester.ensureVisible(createChannelButton);
    await tester.pumpAndSettle();
    expect(find.text('Channels'), findsOneWidget);

    await tester.tap(createChannelButton);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Prensa');
    await tester.enterText(find.byType(TextField).at(1), 'Prensa VIP');
    await tester.enterText(find.byType(TextField).at(2), 'Equipo de prensa');
    await tester.enterText(find.byType(TextField).at(3), '35');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Prensa'), findsOneWidget);
    expect(find.textContaining('prensa-vip'), findsOneWidget);

    final inviteParticipantButton = find.byIcon(Icons.person_add_alt_1);
    await tester.scrollUntilVisible(inviteParticipantButton, 500);
    await tester.tap(inviteParticipantButton);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Sofia');
    await tester.enterText(find.byType(TextField).at(1), '+54 9 264 555-0199');
    final generatedInviteCode =
        tester.widget<TextField>(find.byType(TextField).at(2)).controller!.text;
    expect(generatedInviteCode, matches(RegExp(r'^[A-HJ-NP-Z2-9]{12}$')));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Sofia'), findsOneWidget);
    expect(find.textContaining(generatedInviteCode), findsWidgets);
    expect(
      find.textContaining('$generatedInviteCode · 5 channels'),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('View invite of Sofia'));
    await tester.pumpAndSettle();

    expect(find.text('Invitation of Sofia'), findsOneWidget);
    expect(find.text('Entry code'), findsOneWidget);
    expect(
      find.text('event-radio://join?code=$generatedInviteCode'),
      findsOneWidget,
    );

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Edit channels of Sofia'));
    await tester.pumpAndSettle();

    expect(find.text('Channels of Sofia'), findsOneWidget);
    expect(find.text('Prensa'), findsWidgets);

    await tester.tap(find.byType(Checkbox).last);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('$generatedInviteCode · 4 channels'),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Delete participant Sofia'));
    await tester.pumpAndSettle();
    expect(find.text('Delete participant'), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Sofia'), findsNothing);

    await tester.scrollUntilVisible(find.text('Close now'), -500);
    await tester.tap(find.text('Close now'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Status: closed'), findsOneWidget);
    expect(find.text('Reactivate 8h'), findsOneWidget);

    await tester.tap(find.text('Reactivate 8h'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Status: active'), findsOneWidget);
  });
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
}
