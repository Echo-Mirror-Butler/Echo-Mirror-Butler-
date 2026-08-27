import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import path from 'path'

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },
  server: {
    port: 3000,
    open: true,
    fs: {
      allow: ['..'],
    },
  },
  build: {
    rollupOptions: {
      external: [
        '@sentry/react',
        'jspdf',
        'html-to-image',
        'i18next',
        'react-i18next',
        'i18next-browser-languagedetector',
        'react-simple-maps',
      ],
      output: {
        manualChunks: (id: string) => {
          if (id.includes('node_modules/react') || id.includes('node_modules/react-dom') || id.includes('node_modules/react-router-dom')) return 'vendor'
          if (id.includes('node_modules/@tanstack/react-query')) return 'query'
          if (id.includes('node_modules/@supabase')) return 'supabase'
          if (id.includes('node_modules/recharts')) return 'charts'
        },
      },
    },
  },
})
