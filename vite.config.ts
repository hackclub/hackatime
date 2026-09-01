import inertia from "@inertiajs/vite";
import { svelte } from "@sveltejs/vite-plugin-svelte";
import tailwindcss from "@tailwindcss/vite";
import { defineConfig } from "vite";
import RubyPlugin from "vite-plugin-ruby";

export default defineConfig(({ isSsrBuild }) => ({
  build: {
    sourcemap: isSsrBuild,
  },
  cacheDir: process.env.VITE_CACHE_DIR,
  ssr: {
    noExternal: true,
  },
  server: {
    watch: {
      usePolling: false, // uses a sh*tton of CPU
    },
  },
  plugins: [
    inertia({
      ssr: "ssr/ssr.ts",
    }),
    svelte(),
    tailwindcss(),
    RubyPlugin(),
  ],
}));
