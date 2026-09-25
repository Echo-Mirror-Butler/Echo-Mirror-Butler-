import 'package:echomirror/features/global_mirror/data/services/price_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueFunctions extends Mock implements GoTrueFunctions {}

class MockFunctionResponse extends Mock implements FunctionResponse {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockSupabaseClient mockSupabaseClient;
  late MockGoTrueFunctions mockFunctions;

  setUp(() {
    mockSupabaseClient = MockSupabaseClient();
    mockFunctions = MockGoTrueFunctions();
    PriceService.clearCache();

    when(() => mockSupabaseClient.functions).thenReturn(mockFunctions);
  });

  tearDown(() {
    PriceService.clearCache();
  });

  group('PriceService.getUsdPrice', () {
    test('fetches and caches price for a single coin', () async {
      final mockResponse = MockFunctionResponse();
      when(() => mockResponse.status).thenReturn(200);
      when(() => mockResponse.data).thenReturn({
        'usd_price': 0.12,
        'cached': false,
        'stale': false,
      });

      when(() => mockFunctions.invoke(
            'get-crypto-price',
            body: {'coin': 'stellar'},
          )).thenAnswer((_) async => mockResponse);

      await Supabase.initialize(
        url: 'https://test.supabase.co',
        anonKey: 'test-key',
      );

      final originalClient = Supabase.instance.client;
      try {
        Supabase.instance.client = mockSupabaseClient;

        final result = await PriceService.getUsdPrice('stellar');

        expect(result, isNotNull);
        expect(result!.price, 0.12);
        expect(result.cached, false);
        expect(result.stale, false);

        verify(() => mockFunctions.invoke(
              'get-crypto-price',
              body: {'coin': 'stellar'},
            )).called(1);
      } finally {
        Supabase.instance.client = originalClient;
      }
    });

    test('independently caches prices for different coins', () async {
      await Supabase.initialize(
        url: 'https://test.supabase.co',
        anonKey: 'test-key',
      );

      final originalClient = Supabase.instance.client;
      try {
        Supabase.instance.client = mockSupabaseClient;

        // Mock response for stellar
        final stellarResponse = MockFunctionResponse();
        when(() => stellarResponse.status).thenReturn(200);
        when(() => stellarResponse.data).thenReturn({
          'usd_price': 0.12,
          'cached': false,
          'stale': false,
        });

        when(() => mockFunctions.invoke(
              'get-crypto-price',
              body: {'coin': 'stellar'},
            )).thenAnswer((_) async => stellarResponse);

        // Mock response for bitcoin
        final bitcoinResponse = MockFunctionResponse();
        when(() => bitcoinResponse.status).thenReturn(200);
        when(() => bitcoinResponse.data).thenReturn({
          'usd_price': 45000.00,
          'cached': false,
          'stale': false,
        });

        when(() => mockFunctions.invoke(
              'get-crypto-price',
              body: {'coin': 'bitcoin'},
            )).thenAnswer((_) async => bitcoinResponse);

        // Fetch stellar price
        final stellarResult = await PriceService.getUsdPrice('stellar');
        expect(stellarResult, isNotNull);
        expect(stellarResult!.price, 0.12);

        // Fetch bitcoin price
        final bitcoinResult = await PriceService.getUsdPrice('bitcoin');
        expect(bitcoinResult, isNotNull);
        expect(bitcoinResult!.price, 45000.00);

        // Verify both are cached independently (within cache duration)
        // Clear the mock call history
        clearInteractions(mockFunctions);

        // Fetch stellar again - should come from cache
        final stellarCached = await PriceService.getUsdPrice('stellar');
        expect(stellarCached, isNotNull);
        expect(stellarCached!.price, 0.12);

        // Fetch bitcoin again - should come from cache
        final bitcoinCached = await PriceService.getUsdPrice('bitcoin');
        expect(bitcoinCached, isNotNull);
        expect(bitcoinCached!.price, 45000.00);

        // Verify no new API calls were made (both from cache)
        verifyNever(() => mockFunctions.invoke(
              'get-crypto-price',
              body: any(named: 'body'),
            ));
      } finally {
        Supabase.instance.client = originalClient;
      }
    });

    test('returns null when API returns error status', () async {
      final mockResponse = MockFunctionResponse();
      when(() => mockResponse.status).thenReturn(500);
      when(() => mockResponse.data).thenReturn(null);

      when(() => mockFunctions.invoke(
            'get-crypto-price',
            body: {'coin': 'invalid'},
          )).thenAnswer((_) async => mockResponse);

      await Supabase.initialize(
        url: 'https://test.supabase.co',
        anonKey: 'test-key',
      );

      final originalClient = Supabase.instance.client;
      try {
        Supabase.instance.client = mockSupabaseClient;

        final result = await PriceService.getUsdPrice('invalid');

        expect(result, isNull);
      } finally {
        Supabase.instance.client = originalClient;
      }
    });

    test('returns null when response data is null', () async {
      final mockResponse = MockFunctionResponse();
      when(() => mockResponse.status).thenReturn(200);
      when(() => mockResponse.data).thenReturn(null);

      when(() => mockFunctions.invoke(
            'get-crypto-price',
            body: {'coin': 'stellar'},
          )).thenAnswer((_) async => mockResponse);

      await Supabase.initialize(
        url: 'https://test.supabase.co',
        anonKey: 'test-key',
      );

      final originalClient = Supabase.instance.client;
      try {
        Supabase.instance.client = mockSupabaseClient;

        final result = await PriceService.getUsdPrice('stellar');

        expect(result, isNull);
      } finally {
        Supabase.instance.client = originalClient;
      }
    });

    test('handles stale cache data correctly', () async {
      final mockResponse = MockFunctionResponse();
      when(() => mockResponse.status).thenReturn(200);
      when(() => mockResponse.data).thenReturn({
        'usd_price': 0.11,
        'cached': true,
        'stale': true,
        'age_minutes': 75,
        'warning': 'Price may be outdated',
      });

      when(() => mockFunctions.invoke(
            'get-crypto-price',
            body: {'coin': 'stellar'},
          )).thenAnswer((_) async => mockResponse);

      await Supabase.initialize(
        url: 'https://test.supabase.co',
        anonKey: 'test-key',
      );

      final originalClient = Supabase.instance.client;
      try {
        Supabase.instance.client = mockSupabaseClient;

        final result = await PriceService.getUsdPrice('stellar');

        expect(result, isNotNull);
        expect(result!.price, 0.11);
        expect(result.cached, true);
        expect(result.stale, true);
        expect(result.ageMinutes, 75);
        expect(result.warning, 'Price may be outdated');
      } finally {
        Supabase.instance.client = originalClient;
      }
    });

    test('clearCache removes all cached data', () async {
      await Supabase.initialize(
        url: 'https://test.supabase.co',
        anonKey: 'test-key',
      );

      final originalClient = Supabase.instance.client;
      try {
        Supabase.instance.client = mockSupabaseClient;

        final mockResponse = MockFunctionResponse();
        when(() => mockResponse.status).thenReturn(200);
        when(() => mockResponse.data).thenReturn({
          'usd_price': 0.12,
          'cached': false,
          'stale': false,
        });

        when(() => mockFunctions.invoke(
              'get-crypto-price',
              body: {'coin': 'stellar'},
            )).thenAnswer((_) async => mockResponse);

        // Fetch and cache
        await PriceService.getUsdPrice('stellar');

        // Clear cache
        PriceService.clearCache();

        // Fetch again should make a new API call
        await PriceService.getUsdPrice('stellar');

        // Verify API was called twice (once before clear, once after)
        verify(() => mockFunctions.invoke(
              'get-crypto-price',
              body: {'coin': 'stellar'},
            )).called(2);
      } finally {
        Supabase.instance.client = originalClient;
      }
    });
  });

  group('PriceData', () {
    test('creates instance with all fields', () {
      final priceData = PriceData(
        price: 100.5,
        cached: true,
        stale: false,
        ageMinutes: 3,
        warning: 'Test warning',
      );

      expect(priceData.price, 100.5);
      expect(priceData.cached, true);
      expect(priceData.stale, false);
      expect(priceData.ageMinutes, 3);
      expect(priceData.warning, 'Test warning');
    });

    test('has correct default values', () {
      final priceData = PriceData(price: 50.0);

      expect(priceData.price, 50.0);
      expect(priceData.cached, false);
      expect(priceData.stale, false);
      expect(priceData.ageMinutes, null);
      expect(priceData.warning, null);
    });
  });
}
