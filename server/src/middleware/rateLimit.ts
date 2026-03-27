import rateLimit from 'express-rate-limit';
import { Request, Response } from 'express';

// General rate limiting for all endpoints
export const generalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // limit each IP to 100 requests per windowMs
  message: {
    error: 'Too many requests',
    message: 'Rate limit exceeded. Please try again later.',
    retryAfter: '15 minutes'
  },
  standardHeaders: true,
  legacyHeaders: false,
});

// Strict rate limiting for sensitive endpoints
export const strictLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 10, // limit each IP to 10 requests per windowMs
  message: {
    error: 'Too many requests',
    message: 'Rate limit exceeded for sensitive operations. Please try again later.',
    retryAfter: '15 minutes'
  },
  standardHeaders: true,
  legacyHeaders: false,
});

// Rate limiting for webhooks (higher limit for legitimate traffic)
export const webhookLimiter = rateLimit({
  windowMs: 1 * 60 * 1000, // 1 minute
  max: 1000, // limit each IP to 1000 requests per minute
  message: {
    error: 'Too many webhook requests',
    message: 'Webhook rate limit exceeded. Please try again later.',
    retryAfter: '1 minute'
  },
  standardHeaders: true,
  legacyHeaders: false,
  skip: (req: Request) => {
    // Skip rate limiting for trusted webhook sources
    const trustedSources = [
      'api.stripe.com',
      'hooks.stripe.com',
      'supabase.co',
      'agora.io'
    ];
    
    const origin = req.header('origin') || req.header('x-forwarded-for');
    return trustedSources.some(source => origin?.includes(source));
  }
});

export default {
  generalLimiter,
  strictLimiter,
  webhookLimiter
};
