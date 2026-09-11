import 'package:event_radio_app/src/features/admin/presentation/admin_event_screen.dart';
import 'package:event_radio_app/src/features/admin/presentation/invite_qr_screen.dart';
import 'package:event_radio_app/src/features/channel/presentation/channel_screen.dart';
import 'package:event_radio_app/src/features/event/presentation/event_closed_screen.dart';
import 'package:event_radio_app/src/features/event/presentation/event_home_screen.dart';
import 'package:event_radio_app/src/features/history/presentation/history_screen.dart';
import 'package:event_radio_app/src/features/join/presentation/join_event_screen.dart';
import 'package:event_radio_app/src/features/join/presentation/qr_join_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    // Maneja deep links event-radio://join?code=XXX redirigiendo al flujo
    // de ingreso con el codigo pre-cargado como query parameter.
    redirect: (context, state) {
      final uri = state.uri;
      if (uri.scheme == 'event-radio' && uri.host == 'join') {
        final code = uri.queryParameters['code'];
        if (code != null && code.isNotEmpty) {
          return '/?code=$code';
        }
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        name: 'join',
        builder: (context, state) {
          final code = state.uri.queryParameters['code'];
          return JoinEventScreen(initialCode: code);
        },
      ),
      GoRoute(
        path: '/scan',
        name: 'scan',
        builder: (context, state) => const QrJoinScreen(),
      ),
      GoRoute(
        path: '/event',
        name: 'event',
        builder: (context, state) => const EventHomeScreen(),
      ),
      GoRoute(
        path: '/closed',
        name: 'closed',
        builder: (context, state) => const EventClosedScreen(),
      ),
      GoRoute(
        path: '/channel/:channelId',
        name: 'channel',
        builder: (context, state) => ChannelScreen(
          channelId: state.pathParameters['channelId']!,
        ),
      ),
      GoRoute(
        path: '/history/:channelId',
        name: 'history',
        builder: (context, state) => HistoryScreen(
          channelId: state.pathParameters['channelId']!,
        ),
      ),
      GoRoute(
        path: '/admin',
        name: 'admin',
        builder: (context, state) => const AdminEventScreen(),
      ),
      GoRoute(
        path: '/admin/invite',
        name: 'invite',
        builder: (context, state) => const InviteQrScreen(),
      ),
    ],
  );
});
