import request from 'supertest';
import express from 'express';
import healthRoutes from '../routes/health';

describe('Health Check Routes', () => {
  let app: express.Application;

  beforeAll(() => {
    app = express();
    app.use(express.json());
    app.use('/health', healthRoutes);
  });

  describe('GET /health', () => {
    it('should return health status', async () => {
      const response = await request(app)
        .get('/health')
        .expect(200);

      expect(response.body).toHaveProperty('status', 'ok');
      expect(response.body).toHaveProperty('timestamp');
      expect(response.body).toHaveProperty('uptime');
      expect(response.body).toHaveProperty('environment');
    });

    it('should return valid timestamp format', async () => {
      const response = await request(app)
        .get('/health')
        .expect(200);

      const timestamp = new Date(response.body.timestamp);
      expect(timestamp.toISOString()).toBe(response.body.timestamp);
    });

    it('should return uptime as number', async () => {
      const response = await request(app)
        .get('/health')
        .expect(200);

      expect(typeof response.body.uptime).toBe('number');
      expect(response.body.uptime).toBeGreaterThanOrEqual(0);
    });
  });

  describe('GET /health/detailed', () => {
    it('should return detailed health information', async () => {
      const response = await request(app)
        .get('/health/detailed')
        .expect(200);

      expect(response.body).toHaveProperty('status', 'ok');
      expect(response.body).toHaveProperty('timestamp');
      expect(response.body).toHaveProperty('uptime');
      expect(response.body).toHaveProperty('environment');
      expect(response.body).toHaveProperty('memory');
      expect(response.body).toHaveProperty('cpu');
      expect(response.body).toHaveProperty('node');
    });

    it('should return memory usage information', async () => {
      const response = await request(app)
        .get('/health/detailed')
        .expect(200);

      expect(response.body.memory).toHaveProperty('rss');
      expect(response.body.memory).toHaveProperty('heapTotal');
      expect(response.body.memory).toHaveProperty('heapUsed');
      expect(response.body.memory).toHaveProperty('external');

      // Check that memory values are in MB format
      expect(response.body.memory.rss).toMatch(/^\d+ MB$/);
      expect(response.body.memory.heapTotal).toMatch(/^\d+ MB$/);
    });

    it('should return CPU usage information', async () => {
      const response = await request(app)
        .get('/health/detailed')
        .expect(200);

      expect(response.body.cpu).toHaveProperty('user');
      expect(response.body.cpu).toHaveProperty('system');
      expect(typeof response.body.cpu.user).toBe('number');
      expect(typeof response.body.cpu.system).toBe('number');
    });

    it('should return Node.js version information', async () => {
      const response = await request(app)
        .get('/health/detailed')
        .expect(200);

      expect(response.body.node).toHaveProperty('version');
      expect(response.body.node).toHaveProperty('platform');
      expect(response.body.node).toHaveProperty('arch');

      expect(typeof response.body.node.version).toBe('string');
      expect(typeof response.body.node.platform).toBe('string');
      expect(typeof response.body.node.arch).toBe('string');
    });
  });

  describe('Error handling', () => {
    it('should handle invalid routes gracefully', async () => {
      const response = await request(app)
        .get('/health/invalid')
        .expect(404);

      // Express 404 responses may be empty or have different structure
      // Just verify it returns 404 status
      expect(response.status).toBe(404);
    });
  });
});
