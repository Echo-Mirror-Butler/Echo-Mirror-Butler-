import { Router, Request, Response } from 'express';

const router = Router();

interface AuthenticatedRequest extends Request {
  user?: {
    id: string;
    email: string;
    role: string;
  };
}

router.post('/transaction', async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const { transaction, destination, amount, asset } = req.body;
    
    if (!transaction || !destination || !amount) {
      res.status(400).json({
        error: 'Missing required fields: transaction, destination, amount'
      });
      return;
    }

    console.log(`Processing Stellar transaction for user: ${req.user?.id}`);
    console.log(`Destination: ${destination}, Amount: ${amount}, Asset: ${asset || 'XLM'}`);

    res.status(200).json({
      message: 'Stellar transaction received',
      status: 'pending',
      transactionId: `txn_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
      details: {
        destination,
        amount,
        asset: asset || 'XLM',
        userId: req.user?.id
      }
    });
  } catch (error) {
    console.error('Error processing Stellar transaction:', error);
    res.status(500).json({
      error: 'Failed to process Stellar transaction',
      message: error instanceof Error ? error.message : 'Unknown error'
    });
  }
});

router.get('/balance/:accountId', async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const { accountId } = req.params;
    
    if (!accountId) {
      res.status(400).json({
        error: 'Account ID is required'
      });
      return;
    }

    console.log(`Fetching Stellar balance for account: ${accountId} (User: ${req.user?.id})`);

    const mockBalance = {
      accountId,
      balances: [
        {
          asset_code: 'XLM',
          asset_issuer: null,
          balance: '1000.0000000',
          limit: null
        }
      ],
      lastUpdated: new Date().toISOString()
    };

    res.status(200).json(mockBalance);
  } catch (error) {
    console.error('Error fetching Stellar balance:', error);
    res.status(500).json({
      error: 'Failed to fetch Stellar balance',
      message: error instanceof Error ? error.message : 'Unknown error'
    });
  }
});

export default router;
