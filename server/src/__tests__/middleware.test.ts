import { Request, Response } from 'express';
import { errorHandler } from '../middleware/errorHandler';

describe('Error Handler Middleware', () => {
  let mockRequest: Partial<Request>;
  let mockResponse: Partial<Response>;

  beforeEach(() => {
    mockRequest = {
      url: '/test',
      method: 'GET',
      ip: '127.0.0.1',
      get: jest.fn()
    };
    
    mockResponse = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn().mockReturnThis()
    };
    
  });

  describe('Error Handling', () => {
    it('should handle JWT errors with 401 status', () => {
      const jwtError = new Error('Invalid token');
      jwtError.name = 'JsonWebTokenError';

      errorHandler(
        jwtError,
        mockRequest as Request,
        mockResponse as Response
      );

      expect(mockResponse.status).toHaveBeenCalledWith(401);
      expect(mockResponse.json).toHaveBeenCalledWith(
        expect.objectContaining({
          error: true,
          message: 'Invalid token'
        })
      );
    });

    it('should handle expired token errors', () => {
      const expiredError = new Error('Token expired');
      expiredError.name = 'TokenExpiredError';

      errorHandler(
        expiredError,
        mockRequest as Request,
        mockResponse as Response
      );

      expect(mockResponse.status).toHaveBeenCalledWith(401);
      expect(mockResponse.json).toHaveBeenCalledWith(
        expect.objectContaining({
          error: true,
          message: 'Token expired'
        })
      );
    });

    it('should handle validation errors with 400 status', () => {
      const validationError = new Error('Validation failed');
      validationError.name = 'ValidationError';

      errorHandler(
        validationError,
        mockRequest as Request,
        mockResponse as Response
      );

      expect(mockResponse.status).toHaveBeenCalledWith(400);
      expect(mockResponse.json).toHaveBeenCalledWith(
        expect.objectContaining({
          error: true,
          message: 'Validation failed'
        })
      );
    });

    it('should handle Supabase errors', () => {
      const supabaseError = new Error('Supabase connection failed');

      errorHandler(
        supabaseError,
        mockRequest as Request,
        mockResponse as Response
      );

      expect(mockResponse.status).toHaveBeenCalledWith(500);
      expect(mockResponse.json).toHaveBeenCalledWith(
        expect.objectContaining({
          error: true,
          message: 'Database operation failed'
        })
      );
    });

    it('should handle operational errors with custom status', () => {
      const operationalError = new Error('Custom operational error') as any;
      operationalError.isOperational = true;
      operationalError.statusCode = 418;

      errorHandler(
        operationalError,
        mockRequest as Request,
        mockResponse as Response
      );

      expect(mockResponse.status).toHaveBeenCalledWith(418);
      expect(mockResponse.json).toHaveBeenCalledWith(
        expect.objectContaining({
          error: true,
          message: 'Custom operational error'
        })
      );
    });

    it('should handle generic errors with 500 status', () => {
      const genericError = new Error('Something went wrong');

      errorHandler(
        genericError,
        mockRequest as Request,
        mockResponse as Response
      );

      expect(mockResponse.status).toHaveBeenCalledWith(500);
      expect(mockResponse.json).toHaveBeenCalledWith(
        expect.objectContaining({
          error: true,
          message: 'Internal Server Error'
        })
      );
    });

    it('should include stack trace in development mode', () => {
      const originalEnv = process.env.NODE_ENV;
      process.env.NODE_ENV = 'development';
      
      const error = new Error('Development error');
      error.stack = 'Error stack trace';

      errorHandler(
        error,
        mockRequest as Request,
        mockResponse as Response
      );

      expect(mockResponse.json).toHaveBeenCalledWith(
        expect.objectContaining({
          stack: 'Error stack trace'
        })
      );

      // Restore original env
      process.env.NODE_ENV = originalEnv;
    });

    it('should not include stack trace in production mode', () => {
      const originalEnv = process.env.NODE_ENV;
      process.env.NODE_ENV = 'production';
      
      const error = new Error('Production error');
      error.stack = 'Error stack trace';

      errorHandler(
        error,
        mockRequest as Request,
        mockResponse as Response
      );

      const response = (mockResponse.json as jest.Mock).mock.calls[0][0];
      expect(response.stack).toBeUndefined();

      // Restore original env
      process.env.NODE_ENV = originalEnv;
    });
  });
});
