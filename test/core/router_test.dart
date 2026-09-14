import 'package:event_radio_app/src/app/router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  late GoRouter router;

  setUp(() {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    router = container.read(routerProvider);
  });

  group('routerProvider', () {
    test('provides a GoRouter instance', () {
      expect(router, isA<GoRouter>());
    });

    test('has correct initial location', () {
      expect(router.routeInformationProvider.value.uri.path, '/');
    });
  });

  group('route configuration', () {
    // Extract route paths from the router configuration.
    List<String> extractPaths(List<RouteBase> routes) {
      final paths = <String>[];
      for (final route in routes) {
        if (route is GoRoute) {
          paths.add(route.path);
        }
      }
      return paths;
    }

    test('has 8 routes defined', () {
      final paths = extractPaths(router.configuration.routes);
      expect(paths, hasLength(8));
    });

    test('contains join route at root path', () {
      final paths = extractPaths(router.configuration.routes);
      expect(paths, contains('/'));
    });

    test('contains scan route', () {
      final paths = extractPaths(router.configuration.routes);
      expect(paths, contains('/scan'));
    });

    test('contains event route', () {
      final paths = extractPaths(router.configuration.routes);
      expect(paths, contains('/event'));
    });

    test('contains closed route', () {
      final paths = extractPaths(router.configuration.routes);
      expect(paths, contains('/closed'));
    });

    test('contains channel route with parameter', () {
      final paths = extractPaths(router.configuration.routes);
      expect(paths, contains('/channel/:channelId'));
    });

    test('contains history route with parameter', () {
      final paths = extractPaths(router.configuration.routes);
      expect(paths, contains('/history/:channelId'));
    });

    test('contains admin route', () {
      final paths = extractPaths(router.configuration.routes);
      expect(paths, contains('/admin'));
    });

    test('contains admin invite route', () {
      final paths = extractPaths(router.configuration.routes);
      expect(paths, contains('/admin/invite'));
    });
  });

  group('deep link redirect', () {
    test('router has a top-level redirect configured', () {
      expect(router.configuration.topRedirect, isNotNull);
    });

    test('invite URI has expected scheme and host', () {
      final uri = Uri.parse('event-radio://join?code=ABC123');
      expect(uri.scheme, 'event-radio');
      expect(uri.host, 'join');
      expect(uri.queryParameters['code'], 'ABC123');
    });
  });

  group('route names', () {
    List<String?> extractNames(List<RouteBase> routes) {
      final names = <String?>[];
      for (final route in routes) {
        if (route is GoRoute) {
          names.add(route.name);
        }
      }
      return names;
    }

    test('all routes have names', () {
      final names = extractNames(router.configuration.routes);
      expect(names, everyElement(isNotNull));
    });

    test('route names are unique', () {
      final names = extractNames(router.configuration.routes);
      expect(names.toSet().length, names.length);
    });

    test('contains expected named routes', () {
      final names = extractNames(router.configuration.routes);
      expect(names, containsAll([
        'join',
        'scan',
        'event',
        'closed',
        'channel',
        'history',
        'admin',
        'invite',
      ]));
    });
  });
}
