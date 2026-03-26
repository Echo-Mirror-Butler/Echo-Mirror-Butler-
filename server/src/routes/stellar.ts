import { Router, Request, Response, NextFunction } from 'express';
import { requireAuth, AuthenticatedRequest } from '../middleware/auth';
import { supabase } from '../services/supabase';
import {
  createWallet,
  establishTrustline,
  getWalletBalances,
  sendEcho,
} from '../services/stellar';

export const stellarRouter = Router();

// All routes require a valid JWT
stellarRouter.use(requireAuth);

// POST /stellar/wallet/create
stellarRouter.post(
  '/wallet/create',
  async (req: Request, res: Response, next: NextFunction) => {
    const userId = (req as AuthenticatedRequest).userId;

    try {
      const { data: existing } = await supabase
        .from('user_wallets')
        .select('public_key')
        .eq('user_id', userId)
        .single();

      if (existing) {
        res.status(409).json({
          error: 'Wallet already exists for this user',
          publicKey: existing.public_key,
        });
        return;
      }

      const { publicKey, secretKey } = await createWallet();
      await establishTrustline(secretKey);

      const { error } = await supabase.from('user_wallets').insert({
        user_id: userId,
        public_key: publicKey,
        secret_key: secretKey,
      });

      if (error) throw new Error(`Failed to save wallet: ${error.message}`);

      res.status(201).json({ publicKey, funded: true });
    } catch (err) {
      next(err);
    }
  },
);

// GET /stellar/wallet/balance
stellarRouter.get(
  '/wallet/balance',
  async (req: Request, res: Response, next: NextFunction) => {
    const userId = (req as AuthenticatedRequest).userId;

    try {
      const { data: wallet, error } = await supabase
        .from('user_wallets')
        .select('public_key')
        .eq('user_id', userId)
        .single();

      if (error || !wallet) {
        res.status(404).json({
          error: 'Wallet not found. Call POST /stellar/wallet/create first.',
        });
        return;
      }

      const balances = await getWalletBalances(wallet.public_key);
      res.json({ publicKey: wallet.public_key, ...balances });
    } catch (err) {
      next(err);
    }
  },
);

// POST /stellar/gift
stellarRouter.post(
  '/gift',
  async (req: Request, res: Response, next: NextFunction) => {
    const senderId = (req as AuthenticatedRequest).userId;
    const { recipientUserId, amount, message } = req.body as {
      recipientUserId: string;
      amount: string;
      message?: string;
    };

    if (!recipientUserId || !amount) {
      res.status(400).json({ error: 'recipientUserId and amount are required' });
      return;
    }

    const parsedAmount = parseFloat(amount);
    if (isNaN(parsedAmount) || parsedAmount <= 0) {
      res.status(400).json({ error: 'amount must be a positive number' });
      return;
    }

    if (parsedAmount < 1 || parsedAmount > 100) {
      res.status(400).json({ error: 'amount must be between 1 and 100 ECHO' });
      return;
    }

    if (senderId === recipientUserId) {
      res.status(400).json({ error: 'Cannot gift ECHO to yourself' });
      return;
    }

    try {
      const [senderWallet, recipientWallet] = await Promise.all([
        supabase
          .from('user_wallets')
          .select('public_key, secret_key')
          .eq('user_id', senderId)
          .single(),
        supabase
          .from('user_wallets')
          .select('public_key')
          .eq('user_id', recipientUserId)
          .single(),
      ]);

      if (senderWallet.error || !senderWallet.data) {
        res.status(404).json({ error: 'Sender wallet not found' });
        return;
      }

      if (recipientWallet.error || !recipientWallet.data) {
        res.status(404).json({ error: 'Recipient wallet not found' });
        return;
      }

      const balances = await getWalletBalances(senderWallet.data.public_key);
      if (parseFloat(balances.echo) < parsedAmount) {
        res.status(422).json({
          error: 'Insufficient ECHO balance',
          available: balances.echo,
          requested: amount,
        });
        return;
      }

      const result = await sendEcho(
        senderWallet.data.secret_key,
        recipientWallet.data.public_key,
        parsedAmount.toFixed(7),
        message,
      );

      const { error: insertError } = await supabase
        .from('gift_transactions')
        .insert({
          sender_id: senderId,
          recipient_id: recipientUserId,
          amount: parsedAmount,
          tx_hash: result.txHash,
          status: 'completed',
          message: message ?? null,
        });

      if (insertError) {
        console.error(
          '[stellar/gift] Failed to record transaction:',
          insertError.message,
        );
      }

      res.status(201).json(result);
    } catch (err) {
      const stellarError = err as Error;

      await supabase.from('gift_transactions').insert({
        sender_id: senderId,
        recipient_id: recipientUserId,
        amount: parsedAmount,
        tx_hash: null,
        status: 'failed',
        message: message ?? null,
      });

      if (
        stellarError.message?.includes('op_no_trust') ||
        stellarError.message?.includes('no trustline')
      ) {
        res.status(422).json({ error: 'Recipient has no ECHO trustline' });
        return;
      }

      next(stellarError);
    }
  },
);

// GET /stellar/transactions
stellarRouter.get(
  '/transactions',
  async (req: Request, res: Response, next: NextFunction) => {
    const userId = (req as AuthenticatedRequest).userId;

    const page = Math.max(1, parseInt((req.query.page as string) ?? '1', 10));
    const limit = Math.min(
      100,
      Math.max(1, parseInt((req.query.limit as string) ?? '20', 10)),
    );
    const offset = (page - 1) * limit;

    try {
      const { data, error, count } = await supabase
        .from('gift_transactions')
        .select('*', { count: 'exact' })
        .or(`sender_id.eq.${userId},recipient_id.eq.${userId}`)
        .order('created_at', { ascending: false })
        .range(offset, offset + limit - 1);

      if (error) throw new Error(error.message);

      res.json({
        data: data ?? [],
        pagination: {
          page,
          limit,
          total: count ?? 0,
          totalPages: Math.ceil((count ?? 0) / limit),
        },
      });
    } catch (err) {
      next(err);
    }
  },
);

