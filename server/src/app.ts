import express from 'express';
import { healthRouter } from './routes/health';
import { stellarRouter } from './routes/stellar';

const app = express();

app.use(express.json());
app.use('/health', healthRouter);
app.use('/stellar', stellarRouter);

export { app };
export default app;
