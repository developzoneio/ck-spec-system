import { defineConfig } from 'vite';
import { resolve } from 'path';

export default defineConfig({
  build: {
    lib: {
      entry: resolve(__dirname, 'src/extension.ts'),
      formats: ['cjs'],
      fileName: () => 'extension.js',
    },
    rollupOptions: {
      external: ['vscode'],
      output: {
        entryFileNames: 'extension.js',
      },
    },
    outDir: 'dist',
    sourcemap: true,
    minify: false,
    emptyOutDir: true,
  },
});
