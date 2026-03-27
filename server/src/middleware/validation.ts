import { Request, Response, NextFunction } from 'express';

// Validation middleware factory
export const validateBody = (schema: any) => {
  return (req: Request, res: Response, next: NextFunction): void => {
    const { error } = schema.validate(req.body);
    
    if (error) {
      res.status(400).json({
        error: 'Validation failed',
        message: error.details[0].message,
        details: error.details
      });
      return;
    }
    
    next();
  };
};

// Validation schemas
export const schemas = {
  stellarTransaction: {
    transaction: 'string|required',
    destination: 'string|required|length:56', // Stellar account ID length
    amount: 'number|required|min:0.0000001',
    asset: 'string|optional'
  },
  
  webhookPayload: {
    type: 'string|required',
    data: 'object|required',
    timestamp: 'string|required'
  }
};

// Input sanitization middleware
export const sanitizeInput = (req: Request, res: Response, next: NextFunction) => {
  // Remove potential XSS from strings
  const sanitizeString = (str: string): string => {
    return str.replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, '')
              .replace(/javascript:/gi, '')
              .replace(/on\w+\s*=/gi, '');
  };
  
  // Sanitize request body
  if (req.body && typeof req.body === 'object') {
    const sanitizeObject = (obj: any): any => {
      const sanitized: any = {};
      for (const [key, value] of Object.entries(obj)) {
        if (typeof value === 'string') {
          sanitized[key] = sanitizeString(value);
        } else if (typeof value === 'object' && value !== null) {
          sanitized[key] = sanitizeObject(value);
        } else {
          sanitized[key] = value;
        }
      }
      return sanitized;
    };
    
    req.body = sanitizeObject(req.body);
  }
  
  next();
};

// Content type validation
export const validateContentType = (allowedTypes: string[]) => {
  return (req: Request, res: Response, next: NextFunction): void => {
    const contentType = req.header('Content-Type');
    
    if (!contentType || !allowedTypes.some(type => contentType.includes(type))) {
      res.status(415).json({
        error: 'Unsupported Media Type',
        message: `Content-Type must be one of: ${allowedTypes.join(', ')}`
      });
      return;
    }
    
    next();
  };
};

export default {
  validateBody,
  schemas,
  sanitizeInput,
  validateContentType
};
