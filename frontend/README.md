# EchoMirror Web Frontend

This is the React web application for EchoMirror — a companion web dashboard to the Flutter mobile app.

## Tech Stack

- **Framework**: React 18 + TypeScript
- **Routing**: React Router v6
- **State management**: Zustand
- **Data fetching**: TanStack Query v5
- **Backend**: Supabase JS SDK (same project as the mobile app)
- **Styling**: Tailwind CSS
- **Build tool**: Vite

## Project Structure

```
frontend/
├── src/
│   ├── app/          # Router, providers, global layout
│   ├── features/     # Feature slices (auth, dashboard, logging, socials)
│   ├── components/   # Shared UI components
│   ├── lib/          # Supabase client, utils
│   └── types/        # Shared TypeScript types
├── .env.example      # Environment variables template
├── index.html
├── package.json
├── tailwind.config.ts
├── tsconfig.json
└── vite.config.ts
```

## Getting Started

1. **Install dependencies**:
   ```sh
   cd frontend
   npm install
   ```

2. **Set up environment variables**:
   ```sh
   cp .env.example .env.local
   ```
   Then fill in your Supabase credentials in `.env.local`:
   ```
   VITE_SUPABASE_URL=your_supabase_project_url
   VITE_SUPABASE_ANON_KEY=your_supabase_anon_key
   ```

3. **Start the development server**:
   ```sh
   npm run dev
   ```
   The app will be available at `http://localhost:3000`

4. **Build for production**:
   ```sh
   npm run build
   ```
   The optimized build will be in the `dist/` directory.

## Theme Colors

The app uses the EchoMirror brand colors:
- **Primary Purple**: `#8B5CF6`
- **Secondary Pink**: `#EC4899`

These are configured in `tailwind.config.ts` and available as `primary` and `secondary` color utilities.

## Development Notes

- TypeScript strict mode is enabled
- The Supabase client is initialized in `src/lib/supabase.ts` and will throw an error if environment variables are missing
- All environment variables must be prefixed with `VITE_` to be accessible in the browser
- The app uses TanStack Query for data fetching with a 5-minute stale time by default

See open issues labelled `web` for contribution opportunities.
