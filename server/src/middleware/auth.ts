import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { createClient } from '@supabase/supabase-js';

interface AuthenticatedRequest extends Request {
  user?: {
    id: string;
    email: string;
    role: string;
  };
}

const supabase = createClient(
  process.env.SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!
);

export const authMiddleware = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const authHeader = req.header('Authorization');
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      res.status(401).json({
        error: 'Access denied. No token provided.',
        message: 'Authorization header must be in format: Bearer <token>'
      });
      return;
    }

    const token = authHeader.substring(7);
    if (!token) {
      res.status(401).json({
        error: 'Access denied. No token provided.'
      });
      return;
    }

    const jwtSecret = process.env.JWT_SECRET;
    if (!jwtSecret) {
      console.error('JWT_SECRET not configured');
      res.status(500).json({
        error: 'Server configuration error'
      });
      return;
    }

    try {
      jwt.verify(token, jwtSecret);
      // Token is valid, proceed with user verification
    } catch (jwtError) {
      res.status(401).json({
        error: 'Invalid token',
        message: jwtError instanceof Error ? jwtError.message : 'Token verification failed'
      });
      return;
    }

    const { data: { user }, error } = await supabase.auth.getUser(token);
    if (error || !user) {
      res.status(401).json({
        error: 'Invalid user token',
        message: 'User not found or token expired'
      });
      return;
    }

    const { data: profile, error: profileError } = await supabase
      .from('profiles')
      .select('id, email, role')
      .eq('id', user.id)
      .single();

    if (profileError || !profile) {
      console.warn('User profile not found, using auth user data:', user.id);
      req.user = {
        id: user.id,
        email: user.email || '',
        role: 'user'
      };
    } else {
      req.user = profile;
    }

    console.log(`Authenticated user: ${req.user.id} (${req.user.email}) with role: ${req.user.role}`);
    next();
  } catch (error) {
    console.error('Auth middleware error:', error);
    res.status(500).json({
      error: 'Authentication failed',
      message: error instanceof Error ? error.message : 'Unknown authentication error'
    });
  }
};
