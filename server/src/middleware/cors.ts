import cors from 'cors';
import { Request, Response, NextFunction } from 'express';

// CORS configuration
export const corsOptions = {
  origin: (origin: string | undefined, callback: (err: Error | null, allow?: boolean) => void) => {
    // Allowed origins
    const allowedOrigins = [
      'http://localhost:3000',
      'http://localhost:3001',
      'https://your-production-domain.com',
      'https://your-staging-domain.com'
    ];
    
    // Allow requests with no origin (like mobile apps or curl requests)
    if (!origin) return callback(null, true);
    
    if (allowedOrigins.includes(origin)) {
      callback(null, true);
    } else {
      callback(new Error('Not allowed by CORS'));
    }
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: [
    'Origin',
    'X-Requested-With',
    'Content-Type',
    'Accept',
    'Authorization',
    'X-Supabase-Auth',
    'X-Webhook-Signature'
  ],
  exposedHeaders: ['X-Total-Count', 'X-Rate-Limit-Remaining'],
  maxAge: 86400 // 24 hours
};

// CORS middleware with error handling
export const corsMiddleware = (req: Request, res: Response, next: NextFunction): void => {
  // Handle preflight requests
  if (req.method === 'OPTIONS') {
    res.header('Access-Control-Allow-Origin', '*');
    res.header('Access-Control-Allow-Methods', corsOptions.methods.join(', '));
    res.header('Access-Control-Allow-Headers', corsOptions.allowedHeaders.join(', '));
    res.header('Access-Control-Allow-Credentials', corsOptions.credentials.toString());
    res.header('Access-Control-Max-Age', corsOptions.maxAge.toString());
    res.status(200).send();
    return;
  }
  
  next();
};

// Strict CORS for webhook endpoints
export const webhookCors = cors({
  origin: false, // Only allow same-origin requests for webhooks
  methods: ['POST'],
  allowedHeaders: ['Content-Type', 'X-Webhook-Signature', 'X-Supabase-Signature', 'Stripe-Signature']
});

export default {
  corsOptions,
  corsMiddleware,
  webhookCors
};
