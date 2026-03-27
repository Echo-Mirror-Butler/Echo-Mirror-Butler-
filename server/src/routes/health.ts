import { Router, Request, Response } from 'express';

const router = Router();

// Basic health check
router.get('/', (req: Request, res: Response) => {
  res.json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    environment: process.env.NODE_ENV || 'development'
  });
});

// Detailed health check with system info
router.get('/detailed', (req: Request, res: Response) => {
  const memUsage = process.memoryUsage();
  const cpuUsage = process.cpuUsage();
  
  res.json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    environment: process.env.NODE_ENV || 'development',
    version: process.env.npm_package_version || '1.0.0',
    memory: {
      rss: `${Math.round(memUsage.rss / 1024 / 1024)} MB`,
      heapTotal: `${Math.round(memUsage.heapTotal / 1024 / 1024)} MB`,
      heapUsed: `${Math.round(memUsage.heapUsed / 1024 / 1024)} MB`,
      external: `${Math.round(memUsage.external / 1024 / 1024)} MB`
    },
    cpu: {
      user: cpuUsage.user,
      system: cpuUsage.system
    },
    node: {
      version: process.version,
      platform: process.platform,
      arch: process.arch
    }
  });
});

export default router;
