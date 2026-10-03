import { defineConfig } from 'vite';

export default defineConfig({
  base: './',
  build: {
    // Three.js alone is ~550 kB minified; one chunk is fine for this game.
    chunkSizeWarningLimit: 800,
  },
});
