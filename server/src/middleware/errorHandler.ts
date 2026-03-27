import { Request, Response } from 'express';

export interface AppError extends Error {
  statusCode?: number;
  isOperational?: boolean;
}

export const errorHandler = (
  err: Error | AppError,
  req: Request,
  res: Response
) => {
  const error = { ...err } as AppError;
  error.message = err.message;

  // Log error
  console.error('Error:', {
    message: err.message,
    stack: err.stack,
    url: req.url,
    method: req.method,
    ip: req.ip,
    userAgent: req.get('User-Agent')
  });

  // Default error
  let statusCode = 500;
  let message = 'Internal Server Error';

  // JWT errors
  if (err.name === 'JsonWebTokenError') {
    statusCode = 401;
    message = 'Invalid token';
  } else if (err.name === 'TokenExpiredError') {
    statusCode = 401;
    message = 'Token expired';
  } else if (err.name === 'NotBeforeError') {
    statusCode = 401;
    message = 'Token not active';
  }

  // Validation errors
  if (err.name === 'ValidationError') {
    statusCode = 400;
    message = 'Validation failed';
  }

  // Supabase errors
  if (err.message?.includes('Supabase')) {
    statusCode = 500;
    message = 'Database operation failed';
  }

  // Custom operational errors
  if ((err as AppError).isOperational) {
    statusCode = (err as AppError).statusCode || 500;
    message = err.message;
  }

  // Send error response
  res.status(statusCode).json({
    error: true,
    message,
    ...(process.env.NODE_ENV === 'development' && {
      stack: err.stack,
      details: error
    })
  });
};

export default errorHandler;
