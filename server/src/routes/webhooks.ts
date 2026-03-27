import { Router, Request, Response } from 'express';

const router = Router();

router.post('/supabase', async (req: Request, res: Response) => {
  try {
    const signature = req.header('x-supabase-signature');
    const timestamp = req.header('x-supabase-timestamp');
    
    if (!signature || !timestamp) {
      return res.status(400).json({
        error: 'Missing Supabase webhook headers'
      });
    }

    console.log('Received Supabase webhook:', {
      type: req.body.type,
      table: req.body.table,
      record: req.body.record
    });

    res.status(200).json({ received: true });
  } catch (error) {
    console.error('Error processing Supabase webhook:', error);
    res.status(500).json({
      error: 'Failed to process webhook',
      message: error instanceof Error ? error.message : 'Unknown error'
    });
  }
});

router.post('/stripe', async (req: Request, res: Response) => {
  try {
    const signature = req.header('stripe-signature');
    
    if (!signature) {
      return res.status(400).json({
        error: 'Missing Stripe webhook signature'
      });
    }

    console.log('Received Stripe webhook:', {
      type: req.body.type,
      id: req.body.id
    });

    res.status(200).json({ received: true });
  } catch (error) {
    console.error('Error processing Stripe webhook:', error);
    res.status(500).json({
      error: 'Failed to process webhook',
      message: error instanceof Error ? error.message : 'Unknown error'
    });
  }
});

router.post('/agora', async (req: Request, res: Response) => {
  try {
    console.log('Received Agora webhook:', {
      event: req.body.event,
      channelName: req.body.channelName,
      uid: req.body.uid
    });

    res.status(200).json({ received: true });
  } catch (error) {
    console.error('Error processing Agora webhook:', error);
    res.status(500).json({
      error: 'Failed to process webhook',
      message: error instanceof Error ? error.message : 'Unknown error'
    });
  }
});

export default router;
