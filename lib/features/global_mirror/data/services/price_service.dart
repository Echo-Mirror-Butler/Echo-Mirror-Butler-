import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for fetching crypto prices via backend proxy/cache.
/// Prices are fetched from Supabase edge function which maintains a
/// server-side cache and handles CoinGecko rate limits gracefully.
class PriceService {
  PriceService._();

  static const _cacheDuration = Duration(minutes: 5);
  static DateTime? _lastFetchTime;
  static Map<String, PriceData>? _priceCache;

  /// Fetches the current USD price for a given cryptocurrency.
  /// Returns the price data or null if the fetch fails.
  /// Results are cached for [_cacheDuration].
  static Future<PriceData?> getUsdPrice(String coinId) async {
    try {
      // Return cached price if available and not expired
      if (_priceCache != null &&
          _lastFetchTime != null &&
          DateTime.now().difference(_lastFetchTime!) < _cacheDuration) {
        return _priceCache![coinId];
      }

      final supabase = Supabase.instance.client;
      final response = await supabase.functions.invoke(
        'get-crypto-price',
        body: {'coin': coinId},
      );

      if (response.status == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final price = (data['usd_price'] as num?)?.toDouble();
        
        if (price != null) {
          final priceData = PriceData(
            price: price,
            cached: data['cached'] as bool? ?? false,
            stale: data['stale'] as bool? ?? false,
            ageMinutes: data['age_minutes'] as int?,
            warning: data['warning'] as String?,
          );
          
          _priceCache = {coinId: priceData};
          _lastFetchTime = DateTime.now();
          
          if (priceData.stale) {
            debugPrint(
              '[PriceService] Fetched $coinId price: \$${price} '
              '(stale, age: ${priceData.ageMinutes}min)',
            );
          } else {
            debugPrint('[PriceService] Fetched $coinId price: \$${price}');
          }
          
          return priceData;
        }
      }
    } catch (e) {
      debugPrint('[PriceService] getUsdPrice error: $e');
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

/// Price data with metadata about cache state
class PriceData {
  final double price;
  final bool cached;
  final bool stale;
  final int? ageMinutes;
  final String? warning;

  const PriceData({
    required this.price,
    this.cached = false,
    this.stale = false,
    this.ageMinutes,
    this.warning,
  });
}
