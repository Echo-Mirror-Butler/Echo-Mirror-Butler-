import request from 'supertest';
import app from './index';

describe('server bootstrap', () => {
  it('serves the health endpoint without crashing on import', async () => {
    const response = await request(app).get('/health');

    expect(response.status).toBe(200);
    expect(response.body.status).toBe('ok');
  });
});
