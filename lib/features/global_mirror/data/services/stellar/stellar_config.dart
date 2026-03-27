/// Stellar testnet configuration for ECHO token
class StellarConfig {
  StellarConfig._();

  /// Horizon API endpoint (testnet)
  static const String horizonUrl = 'https://horizon-testnet.stellar.org';

  /// Stellar testnet network passphrase
  static const String networkPassphrase = 'Test SDF Network ; September 2015';

  /// ECHO token asset code
  static const String assetCode = 'ECHO';

  /// Friendbot URL — funds new testnet accounts with XLM
  static const String friendbotUrl = 'https://friendbot.stellar.org';

  /// Issuer public key — set via environment variable at runtime
  /// In production, load from a secrets manager, never hardcode
  static const String issuerPublicKey = String.fromEnvironment(
    'STELLAR_ISSUER_PUBLIC',
    defaultValue: '',
  );
}
