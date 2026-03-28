"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.requireAuth = requireAuth;
const jsonwebtoken_1 = __importDefault(require("jsonwebtoken"));
function requireAuth(req, res, next) {
    const authHeader = req.headers.authorization;
    if (!authHeader?.startsWith('Bearer ')) {
        res.status(401).json({ error: 'Missing or invalid Authorization header' });
        return;
    }
    const token = authHeader.slice(7);
    const secret = process.env.JWT_SECRET;
    if (!secret) {
        res.status(500).json({ error: 'Server misconfiguration: JWT_SECRET not set' });
        return;
    }
    try {
        const payload = jsonwebtoken_1.default.verify(token, secret);
        const userId = payload.sub;
        if (!userId) {
            res.status(401).json({ error: 'Invalid token: missing sub claim' });
            return;
        }
        req.userId = userId;
        next();
    }
    catch {
        res.status(401).json({ error: 'Invalid or expired token' });
    }
}
