# EchoMirror Web Frontend

React + TypeScript web dashboard for wallet gifting, daily logs, and AI insight features.

## Stack

- React + TypeScript (Vite)
- React Router
- TanStack Query
- Supabase JS SDK

## Routes

- `/wallet` — ECHO wallet balance, send gift, transaction history
- `/logs` — paginated list of log entries
- `/logs/new` — create a new log entry
- `/logs/:id/edit` — edit and delete an existing log entry
- `/insights` — generate and browse AI insights

## Local setup

```sh
cd frontend
npm install
cp .env.example .env.local
# Fill in VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY
npm run dev
```

## Validation

```sh
npm run typecheck
npm run build
```
