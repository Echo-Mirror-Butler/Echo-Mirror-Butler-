import express from 'express';
import request from 'supertest';
import jwt from 'jsonwebtoken';
import { stellarRouter } from './stellar';

jest.mock('../services/supabase', () => ({
  supabase: {
    from: jest.fn(),
  },
}));

jest.mock('../services/stellar', () => ({
  createWallet: jest.fn(),
  establishTrustline: jest.fn(),
  getWalletBalances: jest.fn(),
  sendEcho: jest.fn(),
}));

import { supabase } from '../services/supabase';
import {
  createWallet,
  establishTrustline,
  getWalletBalances,
  sendEcho,
} from '../services/stellar';

type QuerySingleResult = {
  data: unknown;
  error: { message: string } | null;
};

const mockedSupabase = supabase as unknown as { from: jest.Mock };
const mockedCreateWallet = createWallet as jest.MockedFunction<typeof createWallet>;
const mockedEstablishTrustline =
  establishTrustline as jest.MockedFunction<typeof establishTrustline>;
const mockedGetWalletBalances =
  getWalletBalances as jest.MockedFunction<typeof getWalletBalances>;
const mockedSendEcho = sendEcho as jest.MockedFunction<typeof sendEcho>;

function authedHeader(userId = 'user_1'): Record<string, string> {
  const token = jwt.sign({}, 'test-secret', { subject: userId });
  return { Authorization: `Bearer ${token}` };
}

function buildSingleQuery(result: QuerySingleResult) {
  return {
    select: jest.fn().mockReturnThis(),
    eq: jest.fn().mockReturnThis(),
    single: jest.fn().mockResolvedValue(result),
  };
}

function buildInsertQuery(result: unknown) {
  return {
    insert: jest.fn().mockResolvedValue(result),
  };
}

function buildTransactionQuery(result: {
  data: unknown[];
  error: { message: string } | null;
  count: number;
}) {
  return {
    select: jest.fn().mockReturnThis(),
    or: jest.fn().mockReturnThis(),
    order: jest.fn().mockReturnThis(),
    range: jest.fn().mockResolvedValue(result),
  };
}

describe('stellar routes', () => {
  const app = express();
  app.use(express.json());
  app.use('/stellar', stellarRouter);
  app.use((err: Error, _req: express.Request, res: express.Response) => {
    res.status(500).json({ error: err.message });
  });

  beforeEach(() => {
    process.env.JWT_SECRET = 'test-secret';
    mockedSupabase.from.mockReset();
    mockedCreateWallet.mockReset();
    mockedEstablishTrustline.mockReset();
    mockedGetWalletBalances.mockReset();
    mockedSendEcho.mockReset();
  });

  describe('POST /stellar/wallet/create', () => {
    it('returns 201 with { publicKey, funded: true } when valid JWT is provided', async () => {
      mockedSupabase.from.mockImplementation((table: string) => {
        if (table === 'user_wallets') {
          return {
            ...buildSingleQuery({ data: null, error: { message: 'not found' } }),
            ...buildInsertQuery({ error: null }),
          };
        }
        throw new Error(`Unexpected table: ${table}`);
      });
      mockedCreateWallet.mockResolvedValue({
        publicKey: 'GBTESTPUBLICKEY',
        secretKey: 'SBTESTSECRET',
      });
      mockedEstablishTrustline.mockResolvedValue();

      const res = await request(app)
        .post('/stellar/wallet/create')
        .set(authedHeader());

      expect(res.status).toBe(201);
      expect(res.body).toEqual({ publicKey: 'GBTESTPUBLICKEY', funded: true });
      expect(mockedCreateWallet).toHaveBeenCalledTimes(1);
      expect(mockedEstablishTrustline).toHaveBeenCalledWith('SBTESTSECRET');
    });

    it('returns 401 without JWT', async () => {
      const res = await request(app).post('/stellar/wallet/create');

      expect(res.status).toBe(401);
      expect(res.body.error).toContain('Authorization');
      expect(mockedCreateWallet).not.toHaveBeenCalled();
    });
  });

  describe('GET /stellar/wallet/balance', () => {
    it('returns balance object when authenticated', async () => {
      mockedSupabase.from.mockImplementation((table: string) => {
        if (table === 'user_wallets') {
          return buildSingleQuery({
            data: { public_key: 'GBUSERWALLET' },
            error: null,
          });
        }
        throw new Error(`Unexpected table: ${table}`);
      });
      mockedGetWalletBalances.mockResolvedValue({ xlm: '100.0', echo: '50.0' });

      const res = await request(app)
        .get('/stellar/wallet/balance')
        .set(authedHeader());

      expect(res.status).toBe(200);
      expect(res.body).toEqual({
        publicKey: 'GBUSERWALLET',
        xlm: '100.0',
        echo: '50.0',
      });
      expect(mockedGetWalletBalances).toHaveBeenCalledWith('GBUSERWALLET');
    });

    it('returns 401 without JWT', async () => {
      const res = await request(app).get('/stellar/wallet/balance');

      expect(res.status).toBe(401);
      expect(res.body.error).toContain('Authorization');
      expect(mockedGetWalletBalances).not.toHaveBeenCalled();
    });
  });

  describe('POST /stellar/gift', () => {
    it('returns { txHash, amount, recipient } on success', async () => {
      mockedSupabase.from.mockImplementation((table: string) => {
        if (table === 'user_wallets') {
          return {
            select: jest.fn().mockReturnThis(),
            eq: jest.fn().mockReturnThis(),
            single: jest
              .fn()
              .mockResolvedValueOnce({
                data: { public_key: 'GBSENDER', secret_key: 'SBSENDER' },
                error: null,
              })
              .mockResolvedValueOnce({
                data: { public_key: 'GBRECIPIENT' },
                error: null,
              }),
          };
        }
        if (table === 'gift_transactions') {
          return buildInsertQuery({ error: null });
        }
        throw new Error(`Unexpected table: ${table}`);
      });
      mockedGetWalletBalances.mockResolvedValue({ xlm: '100.0', echo: '75.0' });
      mockedSendEcho.mockResolvedValue({
        txHash: 'tx_123',
        amount: '10.0000000',
        recipient: 'GBRECIPIENT',
      });

      const res = await request(app)
        .post('/stellar/gift')
        .set(authedHeader('sender_1'))
        .send({
          recipientUserId: 'recipient_1',
          amount: '10',
          message: 'Nice work!',
        });

      expect(res.status).toBe(201);
      expect(res.body).toEqual({
        txHash: 'tx_123',
        amount: '10.0000000',
        recipient: 'GBRECIPIENT',
      });
      expect(mockedSendEcho).toHaveBeenCalled();
    });

    it('returns 422 on insufficient balance', async () => {
      mockedSupabase.from.mockImplementation((table: string) => {
        if (table === 'user_wallets') {
          return {
            select: jest.fn().mockReturnThis(),
            eq: jest.fn().mockReturnThis(),
            single: jest
              .fn()
              .mockResolvedValueOnce({
                data: { public_key: 'GBSENDER', secret_key: 'SBSENDER' },
                error: null,
              })
              .mockResolvedValueOnce({
                data: { public_key: 'GBRECIPIENT' },
                error: null,
              }),
          };
        }
        if (table === 'gift_transactions') {
          return buildInsertQuery({ error: null });
        }
        throw new Error(`Unexpected table: ${table}`);
      });
      mockedGetWalletBalances.mockResolvedValue({ xlm: '100.0', echo: '2.0' });

      const res = await request(app)
        .post('/stellar/gift')
        .set(authedHeader('sender_1'))
        .send({ recipientUserId: 'recipient_1', amount: '10' });

      expect(res.status).toBe(422);
      expect(res.body.error).toContain('Insufficient ECHO balance');
      expect(mockedSendEcho).not.toHaveBeenCalled();
    });

    it('returns 401 without JWT', async () => {
      const res = await request(app)
        .post('/stellar/gift')
        .send({ recipientUserId: 'recipient_1', amount: '10' });

      expect(res.status).toBe(401);
      expect(res.body.error).toContain('Authorization');
      expect(mockedSendEcho).not.toHaveBeenCalled();
    });
  });

  describe('GET /stellar/transactions', () => {
    it('returns paginated transaction history when authenticated', async () => {
      mockedSupabase.from.mockImplementation((table: string) => {
        if (table === 'gift_transactions') {
          return buildTransactionQuery({
            data: [{ id: 'tx1', amount: 10, status: 'completed' }],
            error: null,
            count: 1,
          });
        }
        throw new Error(`Unexpected table: ${table}`);
      });

      const res = await request(app)
        .get('/stellar/transactions?page=1&limit=20')
        .set(authedHeader('user_1'));

      expect(res.status).toBe(200);
      expect(res.body).toEqual({
        data: [{ id: 'tx1', amount: 10, status: 'completed' }],
        pagination: {
          page: 1,
          limit: 20,
          total: 1,
          totalPages: 1,
        },
      });
    });

    it('returns 401 without JWT', async () => {
      const res = await request(app).get('/stellar/transactions');

      expect(res.status).toBe(401);
      expect(res.body.error).toContain('Authorization');
    });
  });
});

