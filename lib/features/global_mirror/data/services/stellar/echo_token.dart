import 'stellar_config.dart';

/// Represents the ECHO custom asset on Stellar testnet.
///
/// ECHO is an in-app token users earn by participating in Global Mirror
/// (sharing mood pins, posting videos, receiving comments) and can gift
/// to other users as a form of appreciation.
class EchoToken {
  EchoToken._();

  /// The Stellar asset code
  static const String code = StellarConfig.assetCode;

  /// The issuer account public key (loaded from environment)
  static String get issuer => StellarConfig.issuerPublicKey;

  /// Minimum gift amount
  static const double minGiftAmount = 1.0;

  /// Maximum gift amount per transaction
  static const double maxGiftAmount = 100.0;

  /// ECHO awarded for sharing a mood pin
  static const double moodPinReward = 2.0;

  /// ECHO awarded for posting a video
  static const double videoPostReward = 5.0;

  /// ECHO awarded for receiving a comment on your pin
  static const double commentReceivedReward = 1.0;

  /// Starting balance for new users
  static const double welcomeBonus = 10.0;
}
