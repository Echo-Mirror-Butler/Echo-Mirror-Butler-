import request from 'supertest';
import express from 'express';
import { healthRouter } from './health';

const app = express();
app.use('/health', healthRouter);

describe('GET /health', () => {
  it('returns 200 with status ok and a timestamp', async () => {
    const res = await request(app).get('/health');
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('ok');
    expect(typeof res.body.timestamp).toBe('string');
    expect(new Date(res.body.timestamp).toISOString()).toBe(res.body.timestamp);
  });
});
