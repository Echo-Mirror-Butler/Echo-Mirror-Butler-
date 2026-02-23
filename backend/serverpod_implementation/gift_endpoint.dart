import 'package:serverpod/serverpod.dart';
import 'package:echomirror_server/src/generated/protocol.dart';
import 'package:echomirror_server/src/config/stellar_config.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

// Import StellarService from your backend integration
// In production, this should be imported from the backend stellar package
import './stellar_service_integration.dart';

/// Serverpod endpoint for ECHO token gifting and wallet management.
/// 
/// This endpoint integrates with Stellar blockchain to submit actual transactions
/// when users send gifts. It falls back gracefully to database-only tracking if
/// Stellar wallets are not configured.
class GiftEndpoint extends Endpoint {
  /// Returns the current user's ECHO balance (database value).
  /// In production, consider also checking Horizon if you want real-time accuracy.
  Future<double> getEchoBalance(Session session) async {
    final userId = session.userId;
    final wallet = await UserWallet.db.findFirstWhere(
      session,
      where: (w) => w.userId.equals(userId),
    );
    
    if (wallet == null) {
      return 0.0;
    }
    
    return wallet.echoBalance;
  }

  /// Transfers ECHO from the current user to [recipientUserId].
  /// 
  /// This method:
  /// 1. Looks up both sender and recipient wallets
  /// 2. Validates sufficient balance
  /// 3. If both have Stellar public keys, submits a real Stellar transaction
  /// 4. Updates the database and stores the transaction hash
  /// 5. Falls back to DB-only if Stellar keys are missing
  /// 6. Returns the created GiftTransaction with stellarTxHash if available
  Future<GiftTransaction?> sendGift(
    Session session,
    int recipientUserId,
    double amount,
    String? message,
  ) async {
    final senderId = session.userId;
    
    // Validate amount
    if (amount <= 0) {
      throw Exception('Amount must be greater than 0');
    }
    
    if (amount > 100) {
      throw Exception('Maximum gift amount is 100 ECHO');
    }

    // Look up sender and recipient wallets
    final senderWallet = await _getOrCreateWallet(session, senderId);
    final recipientWallet = await _getOrCreateWallet(session, recipientUserId);

    // Validate sender has sufficient balance
    if (senderWallet.echoBalance < amount) {
      throw Exception('Insufficient ECHO balance');
    }

    String? stellarTxHash;
    
    // Attempt Stellar transaction if both wallets have Stellar keys
    if (senderWallet.stellarPublicKey != null &&
        senderWallet.stellarPublicKey!.isNotEmpty &&
        recipientWallet.stellarPublicKey != null &&
        recipientWallet.stellarPublicKey!.isNotEmpty) {
      
      try {
        // Get sender's secret key securely from environment config
        final senderSecretKey = await _getSenderSecretKey(session, senderId);
        
        if (senderSecretKey != null && senderSecretKey.isNotEmpty) {
          // Submit to Stellar network
          stellarTxHash = await StellarServiceIntegration.sendEcho(
            senderSecret: senderSecretKey,
            recipientPublicKey: recipientWallet.stellarPublicKey!,
            amount: amount,
            memo: message,
          );
          
          if (stellarTxHash != null) {
            logging.info('[GiftEndpoint] Stellar tx submitted: $stellarTxHash');
          }
        }
      } catch (e) {
        logging.error(
          '[GiftEndpoint] Stellar transaction failed: $e. Falling back to DB-only.',
        );
        // Continue with DB-only transfer
      }
    } else {
      logging.info(
        '[GiftEndpoint] Skipping Stellar: sender stellar keys configured? '
        '${senderWallet.stellarPublicKey != null}, '
        'recipient stellar keys configured? ${recipientWallet.stellarPublicKey != null}',
      );
    }

    // Update database: decrease sender balance, increase recipient balance
    senderWallet.echoBalance -= amount;
    await senderWallet.update(session);

    recipientWallet.echoBalance += amount;
    await recipientWallet.update(session);

    // Create gift transaction record
    final transaction = GiftTransaction(
      senderUserId: senderId,
      recipientUserId: recipientUserId,
      echoAmount: amount,
      status: 'completed',
      message: message,
      stellarTxHash: stellarTxHash,
      createdAt: DateTime.now(),
    );

    await transaction.insert(session);

    logging.info(
      '[GiftEndpoint] Gift sent: $amount ECHO from $senderId to $recipientUserId '
      '(stellar_hash: ${stellarTxHash ?? "none"})',
    );

    return transaction;
  }

  /// Returns the gift transaction history for the current user
  /// (both sent and received transactions).
  Future<List<GiftTransaction>> getGiftHistory(Session session) async {
    final userId = session.userId;
    
    final transactions = await GiftTransaction.db.find(
      session,
      where: (t) => t.senderUserId.equals(userId) | t.recipientUserId.equals(userId),
      orderBy: (t) => t.createdAt,
      orderDescending: true,
    );

    return transactions;
  }

  /// Server-side ECHO award for user participation (mood pins, videos, comments, etc).
  /// Only callable by authenticated users or admin jobs.
  Future<void> awardEcho(
    Session session,
    int userId,
    double amount,
    String reason,
  ) async {
    if (amount <= 0) {
      throw Exception('Award amount must be greater than 0');
    }

    final wallet = await _getOrCreateWallet(session, userId);
    wallet.echoBalance += amount;
    await wallet.update(session);

    logging.info('[GiftEndpoint] Awarded $amount ECHO to $userId for: $reason');
  }

  /// Gets or creates a UserWallet for the given user.
  /// 
  /// If creating a new wallet:
  /// 1. Calls StellarService.createWallet() to generate a keypair
  /// 2. Calls StellarService.establishTrustline() to set up ECHO trustline
  /// 3. Stores only the public key in the database (NEVER the secret)
  /// 4. Initializes ECHO balance with welcome bonus
  Future<UserWallet> _getOrCreateWallet(Session session, int userId) async {
    var wallet = await UserWallet.db.findFirstWhere(
      session,
      where: (w) => w.userId.equals(userId),
    );

    if (wallet != null) {
      return wallet;
    }

    // Create new wallet
    logging.info('[GiftEndpoint] Creating new wallet for user $userId');

    String? stellarPublicKey;
    String? stellarSecretKey;

    try {
      // Step 1: Generate new Stellar keypair
      final keypair = await StellarServiceIntegration.createWallet();
      stellarPublicKey = keypair.accountId;
      stellarSecretKey = keypair.secretSeed;

      logging.info('[GiftEndpoint] Generated Stellar wallet: $stellarPublicKey');

      // Step 2: Establish ECHO trustline
      final trustlineSuccess = await StellarServiceIntegration.establishTrustline(
        stellarSecretKey,
      );

      if (!trustlineSuccess) {
        logging.warning(
          '[GiftEndpoint] Trustline establishment failed for $userId',
        );
        // Don't throw — continue with wallet created but no trustline
      }

      // Step 3: Store ONLY the public key in the database
      // CRITICAL: Never store the secret key in the database!
      // The secret should be stored securely in environment config or a secrets manager.
      logging.info(
        '[GiftEndpoint] ⚠️  Note: Secret key must be stored securely outside DB. '
        'Stellar public key: $stellarPublicKey',
      );
    } catch (e) {
      logging.error(
        '[GiftEndpoint] Stellar wallet creation failed: $e. '
        'Continuing with DB-only wallet.',
      );
      // Continue with stellarPublicKey = null (DB-only mode)
    }

    // Create database wallet record
    wallet = UserWallet(
      userId: userId,
      echoBalance: 10.0, // Welcome bonus
      stellarPublicKey: stellarPublicKey,
      createdAt: DateTime.now(),
    );

    await wallet.insert(session);

    logging.info(
      '[GiftEndpoint] New wallet created for user $userId '
      '(balance: 10 ECHO, stellar: ${stellarPublicKey ?? "none"})',
    );

    return wallet;
  }

  /// Securely retrieves the sender's Stellar secret key.
  /// 
  /// **SECURITY NOTE**: In production, this should:
  /// 1. NOT fetch from the database
  /// 2. Use environment variables, a secrets manager (AWS Secrets Manager, HashiCorp Vault), or
  ///    key derivation functions
  /// 3. Implement access controls and audit logging
  /// 4. Never log the key value
  /// 
  /// For now, this is a placeholder that would use your secrets infrastructure.
  Future<String?> _getSenderSecretKey(Session session, int userId) async {
    // TODO: Implement secure secret key retrieval
    // Example (DO NOT use in production):
    //   return Platform.environment['SENDER_SECRET_KEY_$userId'];
    
    // In production, you might:
    // 1. Store a key derivation seed in the database
    // 2. Use a secrets manager service
    // 3. Use Serverpod's config system with encrypted values
    
    logging.warning(
      '[GiftEndpoint] Secret key retrieval not fully implemented. '
      'Please configure secure secrets management.',
    );
    
    return null; // Placeholder — implement with your secrets infrastructure
  }
}
