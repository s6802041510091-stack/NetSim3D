import react from '@vitejs/plugin-react';
import { defineConfig } from 'vite';

// `npm run dev`: the website on http://localhost:5173, API calls go to the API on port 3000.
export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    // Keep the browser's Host header: the API checks it against Origin on every change.
    proxy: { '/api': { target: 'http://localhost:3000', changeOrigin: false } },
  },
});
