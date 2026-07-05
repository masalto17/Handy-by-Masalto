import 'package:event_radio_app/src/app/event_radio_app.dart';
import 'package:event_radio_app/src/core/config/app_bootstrap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppBootstrap.initialize();

  runApp(
    const ProviderScope(
      child: EventRadioApp(),
    ),
  );
}
