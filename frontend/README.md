# EchoMirror Web Frontend

This directory will contain the React web application for EchoMirror — a companion web dashboard to the Flutter mobile app.

## Planned stack

- **Framework**: React 18 + TypeScript
- **Routing**: React Router v6
- **State management**: Zustand
- **Data fetching**: TanStack Query (React Query)
- **Backend**: Supabase JS SDK (same project as the mobile app)
- **Styling**: Tailwind CSS
- **Charts**: Recharts
- **Build tool**: Vite

## Structure (planned)

```
frontend/
├── src/
│   ├── app/          # Router, providers, global layout
│   ├── features/     # Feature slices (auth, dashboard, logging, socials)
│   ├── components/   # Shared UI components
│   ├── lib/          # Supabase client, utils
│   └── types/        # Shared TypeScript types
├── public/
├── index.html
├── package.json
└── vite.config.ts
```

## Getting started (once scaffolded)

```sh
cd frontend
npm install
cp .env.example .env.local   # fill in VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY
npm run dev
```

See open issues labelled `web` for contribution opportunities.
