class EnvironmentConfig {
  static const String stellarNetwork = String.fromEnvironment(
    'STELLAR_NETWORK',
    defaultValue: 'mainnet',
  );
  
  static bool get isTestnet => stellarNetwork == 'testnet';
}
