import { Router, Request, Response } from 'express';
import GitHubService from '../services/github';

const router = Router();
const githubService = new GitHubService();

// Supabase webhook handler
router.post('/supabase', async (req: Request, res: Response): Promise<void> => {
  try {
    const signature = req.header('x-supabase-signature');
    const timestamp = req.header('x-supabase-timestamp');
    
    if (!signature || !timestamp) {
      res.status(400).json({
        error: 'Missing Supabase webhook headers'
      });
      return;
    }

    console.log('Received Supabase webhook:', {
      type: req.body.type,
      table: req.body.table,
      record: req.body.record
    });

    // TODO: Verify webhook signature
    // TODO: Process webhook payload

    res.status(200).json({ received: true });
  } catch (error) {
    console.error('Error processing Supabase webhook:', error);
    res.status(500).json({
      error: 'Failed to process webhook',
      message: error instanceof Error ? error.message : 'Unknown error'
    });
  }
});

// Stripe webhook handler
router.post('/stripe', async (req: Request, res: Response): Promise<void> => {
  try {
    const signature = req.header('stripe-signature');
    
    if (!signature) {
      res.status(400).json({
        error: 'Missing Stripe webhook signature'
      });
      return;
    }

    console.log('Received Stripe webhook:', {
      type: req.body.type,
      id: req.body.id
    });

    // TODO: Verify webhook signature
    // TODO: Process webhook payload

    res.status(200).json({ received: true });
  } catch (error) {
    console.error('Error processing Stripe webhook:', error);
    res.status(500).json({
      error: 'Failed to process webhook',
      message: error instanceof Error ? error.message : 'Unknown error'
    });
  }
});

// Agora webhook handler
router.post('/agora', async (req: Request, res: Response) => {
  try {
    console.log('Received Agora webhook:', {
      event: req.body.event,
      projectId: req.body.projectId
    });

    // TODO: Verify webhook signature
    // TODO: Process webhook payload

    res.status(200).json({ received: true });
  } catch (error) {
    console.error('Error processing Agora webhook:', error);
    res.status(500).json({
      error: 'Failed to process webhook',
      message: error instanceof Error ? error.message : 'Unknown error'
    });
  }
});

// GitHub webhook handler for issue events
router.post('/github', async (req: Request, res: Response): Promise<void> => {
  try {
    const signature = req.header('x-hub-signature-256');
    
    if (!signature) {
      res.status(400).json({
        error: 'Missing GitHub webhook signature'
      });
      return;
    }

    const eventType = req.header('x-github-event');
    
    if (eventType === 'issues' || eventType === 'issue_comment') {
      const action = req.body.action;
      const issue = req.body.issue;

      console.log('Received GitHub issue webhook:', {
        action,
        issue_number: issue?.number,
        title: issue?.title
      });

      if (issue && (action === 'opened' || action === 'edited' || action === 'closed' || action === 'reopened')) {
        await githubService.syncIssue(issue);
      }

      res.status(200).json({ received: true });
    } else {
      console.log(`Received GitHub webhook event: ${eventType} (not processed)`);
      res.status(200).json({ received: true, note: 'Event type not processed' });
    }
  } catch (error) {
    console.error('Error processing GitHub webhook:', error);
    res.status(500).json({
      error: 'Failed to process webhook',
      message: error instanceof Error ? error.message : 'Unknown error'
    });
  }
});

export default router;
