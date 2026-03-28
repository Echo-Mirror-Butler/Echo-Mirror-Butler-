"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const supertest_1 = __importDefault(require("supertest"));
const jsonwebtoken_1 = __importDefault(require("jsonwebtoken"));
const stellar_1 = require("./stellar");
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
const supabase_1 = require("../services/supabase");
const stellar_2 = require("../services/stellar");
const mockedSupabase = supabase_1.supabase;
const mockedCreateWallet = stellar_2.createWallet;
const mockedEstablishTrustline = stellar_2.establishTrustline;
const mockedGetWalletBalances = stellar_2.getWalletBalances;
const mockedSendEcho = stellar_2.sendEcho;
function authedHeader(userId = 'user_1') {
    const token = jsonwebtoken_1.default.sign({}, 'test-secret', { subject: userId });
    return { Authorization: `Bearer ${token}` };
}
function buildSingleQuery(result) {
    return {
        select: jest.fn().mockReturnThis(),
        eq: jest.fn().mockReturnThis(),
        single: jest.fn().mockResolvedValue(result),
    };
}
function buildInsertQuery(result) {
    return {
        insert: jest.fn().mockResolvedValue(result),
    };
}
function buildTransactionQuery(result) {
    return {
        select: jest.fn().mockReturnThis(),
        or: jest.fn().mockReturnThis(),
        order: jest.fn().mockReturnThis(),
        range: jest.fn().mockResolvedValue(result),
    };
}
describe('stellar routes', () => {
    const app = (0, express_1.default)();
    app.use(express_1.default.json());
    app.use('/stellar', stellar_1.stellarRouter);
    app.use((err, _req, res) => {
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
            mockedSupabase.from.mockImplementation((table) => {
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
            const res = await (0, supertest_1.default)(app)
                .post('/stellar/wallet/create')
                .set(authedHeader());
            expect(res.status).toBe(201);
            expect(res.body).toEqual({ publicKey: 'GBTESTPUBLICKEY', funded: true });
            expect(mockedCreateWallet).toHaveBeenCalledTimes(1);
            expect(mockedEstablishTrustline).toHaveBeenCalledWith('SBTESTSECRET');
        });
        it('returns 401 without JWT', async () => {
            const res = await (0, supertest_1.default)(app).post('/stellar/wallet/create');
            expect(res.status).toBe(401);
            expect(res.body.error).toContain('Authorization');
            expect(mockedCreateWallet).not.toHaveBeenCalled();
        });
    });
    describe('GET /stellar/wallet/balance', () => {
        it('returns balance object when authenticated', async () => {
            mockedSupabase.from.mockImplementation((table) => {
                if (table === 'user_wallets') {
                    return buildSingleQuery({
                        data: { public_key: 'GBUSERWALLET' },
                        error: null,
                    });
                }
                throw new Error(`Unexpected table: ${table}`);
            });
            mockedGetWalletBalances.mockResolvedValue({ xlm: '100.0', echo: '50.0' });
            const res = await (0, supertest_1.default)(app)
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
            const res = await (0, supertest_1.default)(app).get('/stellar/wallet/balance');
            expect(res.status).toBe(401);
            expect(res.body.error).toContain('Authorization');
            expect(mockedGetWalletBalances).not.toHaveBeenCalled();
        });
    });
    describe('POST /stellar/gift', () => {
        it('returns { txHash, amount, recipient } on success', async () => {
            mockedSupabase.from.mockImplementation((table) => {
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
            const res = await (0, supertest_1.default)(app)
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
            mockedSupabase.from.mockImplementation((table) => {
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
            const res = await (0, supertest_1.default)(app)
                .post('/stellar/gift')
                .set(authedHeader('sender_1'))
                .send({ recipientUserId: 'recipient_1', amount: '10' });
            expect(res.status).toBe(422);
            expect(res.body.error).toContain('Insufficient ECHO balance');
            expect(mockedSendEcho).not.toHaveBeenCalled();
        });
        it('returns 401 without JWT', async () => {
            const res = await (0, supertest_1.default)(app)
                .post('/stellar/gift')
                .send({ recipientUserId: 'recipient_1', amount: '10' });
            expect(res.status).toBe(401);
            expect(res.body.error).toContain('Authorization');
            expect(mockedSendEcho).not.toHaveBeenCalled();
        });
    });
    describe('GET /stellar/transactions', () => {
        it('returns paginated transaction history when authenticated', async () => {
            mockedSupabase.from.mockImplementation((table) => {
                if (table === 'gift_transactions') {
                    return buildTransactionQuery({
                        data: [{ id: 'tx1', amount: 10, status: 'completed' }],
                        error: null,
                        count: 1,
                    });
                }
                throw new Error(`Unexpected table: ${table}`);
            });
            const res = await (0, supertest_1.default)(app)
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
            const res = await (0, supertest_1.default)(app).get('/stellar/transactions');
            expect(res.status).toBe(401);
            expect(res.body.error).toContain('Authorization');
        });
    });
});
