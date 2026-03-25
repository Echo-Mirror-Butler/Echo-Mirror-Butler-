import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import { stellarRouter } from './routes/stellar';
import { errorHandler } from './middleware/errorHandler';

const app = express();
const PORT = process.env.PORT ?? 3000;

app.use(cors());
app.use(express.json());

app.get('/health', (_req, res) => {
  res.json({ status: 'ok' });
});

app.use('/stellar', stellarRouter);

app.use(errorHandler);

app.listen(PORT, () => {
  console.log(`EchoMirror Stellar server running on port ${PORT}`);
});
