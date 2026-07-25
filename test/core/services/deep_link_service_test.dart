import 'package:echomirror/core/services/deep_link_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DeepLinkService - custom scheme parsing', () {
    late DeepLinkService service;

    setUp(() {
      service = DeepLinkService();
    });

    test('gift link maps to /gift/:userId', () {
      final uri = Uri.parse('echomirror://gift/user123');
      final route = service._mapCustomSchemeLink(uri);
      expect(route, '/gift/user123');
    });

    test('leaderboard link maps to /leaderboard', () {
      final uri = Uri.parse('echomirror://leaderboard');
      final route = service._mapCustomSchemeLink(uri);
      expect(route, '/leaderboard');
    });

    test('log detail link maps to /logging/detail/:id', () {
      final uri = Uri.parse('echomirror://log/log456');
      final route = service._mapCustomSchemeLink(uri);
      expect(route, '/logging/detail/log456');
    });

    test('gift link with missing userId returns null', () {
      final uri = Uri.parse('echomirror://gift');
      final route = service._mapCustomSchemeLink(uri);
      expect(route, null);
    });

    test('gift link with empty userId returns null', () {
      final uri = Uri.parse('echomirror://gift/');
      final route = service._mapCustomSchemeLink(uri);
      expect(route, null);
    });

    test('log link with missing id returns null', () {
      final uri = Uri.parse('echomirror://log');
      final route = service._mapCustomSchemeLink(uri);
      expect(route, null);
    });

    test('unknown path returns null', () {
      final uri = Uri.parse('echomirror://unknown/path');
      final route = service._mapCustomSchemeLink(uri);
      expect(route, null);
    });

    test('empty path returns null', () {
      final uri = Uri.parse('echomirror://');
      final route = service._mapCustomSchemeLink(uri);
      expect(route, null);
    });

    test('auth callback is not mapped as content', () {
      final uri = Uri.parse('echomirror://auth/callback');
      final route = service._mapCustomSchemeLink(uri);
      expect(route, null);
    });
  });

  group('DeepLinkService - universal link parsing', () {
    late DeepLinkService service;

    setUp(() {
      service = DeepLinkService();
    });

    test('gift link maps to /gift/:userId', () {
      final uri = Uri.parse('https://echomirrorbutler.vercel.app/gift/user123');
      final route = service._mapUniversalLink(uri);
      expect(route, '/gift/user123');
    });

    test('leaderboard link maps to /leaderboard', () {
      final uri = Uri.parse('https://echomirrorbutler.vercel.app/leaderboard');
      final route = service._mapUniversalLink(uri);
      expect(route, '/leaderboard');
    });

    test('log detail link maps to /logging/detail/:id', () {
      final uri = Uri.parse('https://echomirrorbutler.vercel.app/log/log456');
      final route = service._mapUniversalLink(uri);
      expect(route, '/logging/detail/log456');
    });

    test('unknown host returns null', () {
      final uri = Uri.parse('https://other-site.com/leaderboard');
      final route = service._mapUniversalLink(uri);
      expect(route, null);
    });

    test('gift with missing userId returns null', () {
      final uri = Uri.parse('https://echomirrorbutler.vercel.app/gift');
      final route = service._mapUniversalLink(uri);
      expect(route, null);
    });

    test('unknown path returns null', () {
      final uri = Uri.parse('https://echomirrorbutler.vercel.app/unknown');
      final route = service._mapUniversalLink(uri);
      expect(route, null);
    });

    test('auth callback is not mapped as content', () {
      final uri = Uri.parse('https://echomirrorbutler.vercel.app/auth/callback');
      final route = service._mapUniversalLink(uri);
      expect(route, null);
    });
  });

  group('DeepLinkService - pending route', () {
    late DeepLinkService service;

    setUp(() {
      service = DeepLinkService();
    });

    test('consumePendingRoute returns null when no route saved', () async {
      final route = await service.consumePendingRoute();
      expect(route, null);
    });

    test('consumePendingRoute returns and clears saved route', () async {
      await service._savePendingRoute('/gift/user123');
      final route = await service.consumePendingRoute();
      expect(route, '/gift/user123');

      // Second call should return null
      final secondCall = await service.consumePendingRoute();
      expect(secondCall, null);
    });
  });
}
