import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import { stellarRouter } from './routes/stellar';
import { healthRouter } from './routes/health';
import { moderationRouter } from './routes/moderation';
import { errorHandler } from './middleware/errorHandler';

const REQUIRED_ENV_VARS = [
  'SUPABASE_URL',
  'SUPABASE_SERVICE_ROLE_KEY',
  'STELLAR_SECRET_KEY',
  'ECHO_ASSET_ISSUER',
];

const missing = REQUIRED_ENV_VARS.filter((key) => !process.env[key]);
if (missing.length > 0) {
  throw new Error(`Missing required environment variables: ${missing.join(', ')}`);
}

const app = express();
const PORT = process.env.PORT ?? 3000;

app.use(cors());
app.use(express.json());

app.use('/health', healthRouter);
app.use('/stellar', stellarRouter);
app.use('/moderation', moderationRouter);

app.use(errorHandler);

app.listen(PORT, () => {
  console.log(`EchoMirror Stellar server running on port ${PORT}`);
});

export { app };
