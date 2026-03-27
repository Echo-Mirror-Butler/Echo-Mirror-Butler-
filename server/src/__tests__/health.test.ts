import request from 'supertest';
import express from 'express';

// Import just the health routes to avoid Supabase dependency
import healthRoutes from '../routes/health';

describe('Health Endpoints', () => {
  let app: express.Application;

  beforeEach(() => {
    app = express();
    app.use('/health', healthRoutes);
  });

  it('should return health status', async () => {
    const response = await request(app)
      .get('/health')
      .expect(200);

    expect(response.body).toHaveProperty('status', 'ok');
    expect(response.body).toHaveProperty('timestamp');
    expect(response.body).toHaveProperty('uptime');
  });

  it('should return detailed health status', async () => {
    const response = await request(app)
      .get('/health/detailed')
      .expect(200);

    expect(response.body).toHaveProperty('status', 'ok');
    expect(response.body).toHaveProperty('memory');
    expect(response.body).toHaveProperty('cpu');
  });
});
