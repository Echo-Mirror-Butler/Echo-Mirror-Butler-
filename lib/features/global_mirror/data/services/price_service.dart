import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http_client;

/// Service for fetching crypto prices from CoinGecko API (free, no authentication).
class PriceService {
  PriceService._();

  static const _baseUrl = 'https://api.coingecko.com/api/v3';
  static const _cacheDuration = Duration(minutes: 5);
  static DateTime? _lastFetchTime;
  static Map<String, double>? _priceCache;

  /// Fetches the current USD price for a given cryptocurrency.
  /// Returns the price or null if the fetch fails.
  /// Results are cached for [_cacheDuration].
  static Future<double?> getUsdPrice(
    String coinId, {
    http_client.Client? httpClient,
  }) async {
    try {
      // Return cached price if available and not expired
      if (_priceCache != null &&
          _lastFetchTime != null &&
          DateTime.now().difference(_lastFetchTime!) < _cacheDuration) {
        return _priceCache![coinId];
      }

      final client = httpClient ?? http_client.Client();
      try {
        final url = Uri.parse(
          '$_baseUrl/simple/price?ids=stellar&vs_currencies=usd',
        );
        final response = await client.get(url);

        if (response.statusCode == 200) {
          final json = response.body;
          final price = _parsePrice(json, coinId);
          if (price != null) {
            _priceCache = {coinId: price};
            _lastFetchTime = DateTime.now();
            debugPrint('[PriceService] Fetched $coinId price: \$$price');
            return price;
          }
        }
      } finally {
        if (httpClient == null) {
          client.close();
        }
      }
    } catch (e) {
      debugPrint('[PriceService] getUsdPrice error: $e');
    }
    return null;
  }

  /// Parses the price from the raw JSON response.
  static double? _parsePrice(String jsonString, String coinId) {
    try {
      if (jsonString.contains('"usd"')) {
        final usdIndex = jsonString.indexOf('"usd"');
        final colonIndex = jsonString.indexOf(':', usdIndex);
        final commaOrBrace = jsonString.indexOf(
          RegExp('[,}]'),
          colonIndex,
        );
        if (colonIndex != -1 && commaOrBrace != -1) {
          final priceStr =
              jsonString.substring(colonIndex + 1, commaOrBrace).trim();
          return double.tryParse(priceStr);
        }
      }
    } catch (e) {
      debugPrint('[PriceService] _parsePrice error: $e');
    }
    return null;
  }

  /// Clears the cached price data.
  @visibleForTesting
  static void clearCache() {
    _priceCache = null;
    _lastFetchTime = null;
  }
}
