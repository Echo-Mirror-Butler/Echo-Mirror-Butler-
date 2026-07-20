import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import rateLimit from 'express-rate-limit';
import dotenv from 'dotenv';

// Import routes
import healthRoutes from './routes/health';
import stellarRoutes from './routes/stellar';
import webhookRoutes from './routes/webhooks';

// Load environment variables
dotenv.config();

const createApp = () => {
  const app = express();

  // Security middleware
  app.use(helmet());
  app.use(cors({
    origin: process.env.CORS_ORIGIN || 'http://localhost:3000',
    credentials: true
  }));

  // Rate limiting
  const limiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: 100, // limit each IP to 100 requests per windowMs
    message: 'Too many requests from this IP, please try again later.'
  });
  app.use(limiter);

  // Logging
  app.use(morgan('combined'));

  // Body parsing
  app.use(express.json({ limit: '10mb' }));
  app.use(express.urlencoded({ extended: true }));

  // Health check routes
  app.use('/health', healthRoutes);

  // Protected API routes
  app.use('/stellar', stellarRoutes);
  app.use('/webhooks', webhookRoutes);

  // Root endpoint
  app.get('/', (req, res) => {
    res.json({
      message: 'Echo Mirror Butler Server API',
      version: '1.0.0',
      status: 'running',
      endpoints: {
        health: '/health',
        stellar: '/stellar',
        webhooks: '/webhooks'
      }
    });
  });

  // 404 handler
  app.use('*', (req, res) => {
    res.status(404).json({
      error: 'Endpoint not found',
      message: `Cannot ${req.method} ${req.originalUrl}`,
      availableEndpoints: ['/health', '/stellar', '/webhooks']
    });
  });

  // Global error handler
  app.use((err: any, req: express.Request, res: express.Response, _next: express.NextFunction) => {
    console.error('Unhandled error:', err);
    res.status(err.status || 500).json({
      error: 'Internal server error',
      message: process.env.NODE_ENV === 'development' ? err.message : 'Something went wrong',
      ...(process.env.NODE_ENV === 'development' && { stack: err.stack })
    });
  });

  return app;
};

const app = createApp();
const PORT = process.env.PORT || 3000;

if (require.main === module) {
  app.listen(PORT, () => {
    console.log(`🚀 Echo Mirror Butler Server running on port ${PORT}`);
    console.log(`📊 Health check: http://localhost:${PORT}/health`);
    console.log(`⭐ Stellar API: http://localhost:${PORT}/stellar`);
    console.log(`🔗 Webhooks: http://localhost:${PORT}/webhooks`);
  });
}

export { createApp };
export default app;
