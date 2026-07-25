import { Router, Request, Response, NextFunction } from 'express';
import { requireAuth, AuthenticatedRequest } from '../middleware/auth';
import { supabase } from '../services/supabase';

export const moderationRouter = Router();

// Middleware to check if user is admin/moderator
async function requireAdmin(req: Request, res: Response, next: NextFunction) {
  const userId = (req as AuthenticatedRequest).userId;
  const { data: profile, error } = await supabase
    .from('profiles')
    .select('role')
    .eq('id', userId)
    .single();

  if (error || !profile || !['admin', 'moderator'].includes(profile.role)) {
    res.status(403).json({ error: 'Unauthorized: admin role required' });
    return;
  }

  next();
}

// All routes require authentication
moderationRouter.use(requireAuth);

// ─────────────────────────────────────────────
// POST /moderation/report
// Report inappropriate content
// Body: { content_type, content_id, reason }
// ─────────────────────────────────────────────
moderationRouter.post(
  '/report',
  async (req: Request, res: Response, next: NextFunction) => {
    const userId = (req as AuthenticatedRequest).userId;
    const { content_type, content_id, reason } = req.body;

    if (!content_type || !content_id || !reason) {
      res.status(400).json({ error: 'content_type, content_id, and reason are required' });
      return;
    }

    try {
      const { data, error } = await supabase
        .from('reported_content')
        .insert({
          content_type,
          content_id,
          reported_by: userId,
          reason,
          status: 'pending',
        })
        .select();

      if (error) throw error;

      res.status(201).json(data?.[0]);
    } catch (err) {
      next(err);
    }
  },
);

// ─────────────────────────────────────────────
// GET /moderation/reports
// Get all reports (admin only)
// Query: status (pending, reviewed, dismissed, action_taken), limit, offset
// ─────────────────────────────────────────────
moderationRouter.get(
  '/reports',
  requireAdmin,
  async (req: Request, res: Response, next: NextFunction) => {
    const status = req.query.status as string;
    const limit = Math.min(100, Math.max(1, parseInt((req.query.limit as string) ?? '20', 10)));
    const offset = Math.max(0, parseInt((req.query.offset as string) ?? '0', 10));

    try {
      let query = supabase
        .from('reported_content')
        .select('*', { count: 'exact' })
        .order('created_at', { ascending: false });

      if (status) {
        query = query.eq('status', status);
      }

      const { data, error, count } = await query.range(offset, offset + limit - 1);

      if (error) throw error;

      res.json({
        data: data ?? [],
        pagination: { limit, offset, total: count ?? 0 },
      });
    } catch (err) {
      next(err);
    }
  },
);

// ─────────────────────────────────────────────
// PATCH /moderation/reports/:reportId
// Update report status (admin only)
// Body: { status, admin_notes? }
// ─────────────────────────────────────────────
moderationRouter.patch(
  '/reports/:reportId',
  requireAdmin,
  async (req: Request, res: Response, next: NextFunction) => {
    const userId = (req as AuthenticatedRequest).userId;
    const { reportId } = req.params;
    const { status, admin_notes } = req.body;

    if (!status) {
      res.status(400).json({ error: 'status is required' });
      return;
    }

    try {
      const { data, error } = await supabase
        .from('reported_content')
        .update({
          status,
          admin_notes: admin_notes ?? null,
          resolved_at: new Date().toISOString(),
          resolved_by: userId,
        })
        .eq('id', reportId)
        .select();

      if (error) throw error;

      if (!data || data.length === 0) {
        res.status(404).json({ error: 'Report not found' });
        return;
      }

      // Log audit action
      await supabase.rpc('log_audit_action', {
        p_action: 'update_report',
        p_target_type: 'reported_content',
        p_target_id: reportId,
        p_details: { status, notes: admin_notes },
      });

      res.json(data[0]);
    } catch (err) {
      next(err);
    }
  },
);

// ─────────────────────────────────────────────
// GET /moderation/audit-logs
// Get audit logs (admin only)
// Query: limit, offset
// ─────────────────────────────────────────────
moderationRouter.get(
  '/audit-logs',
  requireAdmin,
  async (req: Request, res: Response, next: NextFunction) => {
    const limit = Math.min(100, Math.max(1, parseInt((req.query.limit as string) ?? '20', 10)));
    const offset = Math.max(0, parseInt((req.query.offset as string) ?? '0', 10));

    try {
      const { data, error, count } = await supabase
        .from('audit_log')
        .select('*', { count: 'exact' })
        .order('created_at', { ascending: false })
        .range(offset, offset + limit - 1);

      if (error) throw error;

      res.json({
        data: data ?? [],
        pagination: { limit, offset, total: count ?? 0 },
      });
    } catch (err) {
      next(err);
    }
  },
);

// ─────────────────────────────────────────────
// GET /moderation/error-logs
// Get error logs (admin only)
// Query: limit, offset
// ─────────────────────────────────────────────
moderationRouter.get(
  '/error-logs',
  requireAdmin,
  async (req: Request, res: Response, next: NextFunction) => {
    const limit = Math.min(100, Math.max(1, parseInt((req.query.limit as string) ?? '20', 10)));
    const offset = Math.max(0, parseInt((req.query.offset as string) ?? '0', 10));

    try {
      const { data, error, count } = await supabase
        .from('error_logs')
        .select('*', { count: 'exact' })
        .order('created_at', { ascending: false })
        .range(offset, offset + limit - 1);

      if (error) throw error;

      res.json({
        data: data ?? [],
        pagination: { limit, offset, total: count ?? 0 },
      });
    } catch (err) {
      next(err);
    }
  },
);
