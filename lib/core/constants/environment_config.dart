/// Runtime environment configuration.
///
/// Detects whether the build is targeting the Stellar testnet or mainnet
/// so the app can adjust behaviour (e.g. show Friendbot funding controls
/// only on testnet).
///
/// The network is resolved at runtime from the `--dart-define` flag
/// (e.g. `flutter run --dart-define=STELLAR_NETWORK=testnet`). When unset,
/// the app defaults to **testnet** to keep development friction low.
class EnvironmentConfig {
  EnvironmentConfig._();

  /// Network identifier resolved from compile-time defines.
  /// Defaults to `testnet` when no `--dart-define` is provided so that
  /// new testers always have a working Friendbot path.
  static const String _rawNetwork = String.fromEnvironment(
    'STELLAR_NETWORK',
    defaultValue: 'testnet',
  );

  /// True when the current build targets Stellar testnet.
  static bool get isTestnet => _rawNetwork.toLowerCase() != 'mainnet';

  /// Resolved network identifier (`testnet` or `mainnet`).
  static String get network => isTestnet ? 'testnet' : 'mainnet';
}
