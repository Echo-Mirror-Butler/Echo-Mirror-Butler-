/// Minimal Stellar keypair representation for server-side use.
///
/// Replace with a Dart-compatible Stellar library (e.g. a pure-Dart Horizon
/// HTTP client) when real on-chain operations are required.
class StellarKeyPair {
  final String accountId;
  final String secretSeed;
  StellarKeyPair({required this.accountId, required this.secretSeed});
}

/// Server-side stub for Stellar operations.
///
/// `stellar_flutter_sdk` requires the Flutter engine and cannot run on a
/// Dart-only Serverpod server. All methods here either return safe no-op
/// values or throw, so that [GiftEndpoint] falls back to DB-only mode
/// automatically via its existing try/catch blocks.
///
/// To enable real on-chain transfers, replace this file with an
/// implementation backed by a pure-Dart Stellar library or direct
/// Horizon REST API calls.
class StellarService {
  StellarService._();

  /// Always throws — [GiftEndpoint._getOrCreateWallet] catches this and
  /// creates the wallet in DB-only mode (no Stellar public key stored).
  static Future<StellarKeyPair> createWallet() async {
    throw UnsupportedError(
      'StellarService is not yet implemented for the Dart server. '
      'Replace with a pure-Dart Stellar library.',
    );
  }

  /// Returns false — no trustline is established in stub mode.
  static Future<bool> establishTrustline(String userSecret) async {
    return false;
  }

  /// Returns null — [GiftEndpoint.sendGift] skips Stellar and falls back
  /// to a DB-only balance update.
  static Future<String?> sendEcho({
    required String senderSecret,
    required String recipientPublicKey,
    required double amount,
    String? memo,
  }) async {
    return null;
  }

  /// Returns null — [GiftEndpoint.sendGift] skips the on-chain transfer
  /// when no secret key is available.
  static String? getSecretKey(int userId) {
    return null;
  }
}
