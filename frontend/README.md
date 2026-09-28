# EchoMirror Web Frontend

React + TypeScript web dashboard for wallet gifting, daily logs, and AI insight features.

## Stack

- React + TypeScript (Vite)
- React Router
- TanStack Query
- Supabase JS SDK
- Custom CSS design system

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

## Production security headers

Vercel applies the headers in `vercel.json` to every route, including static
files. The Content Security Policy is enforced (not report-only) and follows
the resources currently loaded by the frontend:

- scripts, workers, the web app manifest, and default resources are limited to
  this origin; blob workers are allowed for the Sentry replay integration;
- Google Fonts is allowed for styles and font files, while inline styles remain
  allowed because React components set style attributes at runtime;
- images are limited to this origin, data/blob previews, the configured
  Supabase project, GitHub contributor avatars, Pexels posters, and the wallet
  QR-code service;
- media is limited to the Pexels videos used on the landing page;
- network connections are limited to the configured Supabase project (HTTPS
  and Realtime WebSocket), the GitHub contributors API, the jsDelivr world-map
  data, Stellar Horizon mainnet/testnet, and standard Sentry ingest hosts.
  Friendbot is opened through top-level navigation and does not require a
  `connect-src` exception.

The policy also blocks plugins and framing, restricts forms and base URLs to
this origin, and upgrades insecure requests. `X-Content-Type-Options`,
`Referrer-Policy`, `X-Frame-Options`, and a least-privilege
`Permissions-Policy` provide defense in depth. Vercel already supplies HSTS
for production responses, so `vercel.json` does not duplicate it. Geolocation,
clipboard writes, and Web Share remain available to this origin because the
Global Mirror and sharing flows use them; unused sensitive capabilities are
disabled.

Vite emits content-hashed bundles under `/assets/`. Those responses receive a
one-year immutable cache policy; HTML and other unhashed files deliberately do
not, so deployments can update them immediately.

If a deployment changes `VITE_SUPABASE_URL`, `VITE_STELLAR_HORIZON_URL`, or
uses a non-standard `VITE_SENTRY_DSN` ingest host, update the corresponding CSP
source at the same time. After changing the policy, check a Vercel preview with
`curl -I`, exercise landing, sign-in, and dashboard flows with Playwright, and
confirm that the browser console contains no CSP violations before promotion.
