import inertia from "@inertiajs/vite";
import { svelte } from "@sveltejs/vite-plugin-svelte";
import tailwindcss from "@tailwindcss/vite";
import { defineConfig } from "vite";
import RubyPlugin from "vite-plugin-ruby";
import type { CodeSplittingGroup } from "rolldown";

const chunkGroups: CodeSplittingGroup[] = [
  { name: "vendor-layerchart", test: /[\\/]layerchart[\\/]/, priority: 20 },
  { name: "vendor-bits-ui", test: /[\\/]bits-ui[\\/]/, priority: 20 },
  {
    name: "vendor-icons",
    test: /[\\/](svelte-hero-icons|hcicons-svelte)[\\/]/,
    priority: 20,
  },
  {
    name: "js-routes",
    test: /[\\/]app[\\/]javascript[\\/]api[\\/]/,
    priority: 15,
  },
  { name: "common", minShareCount: 2, priority: 5 },
];

export default defineConfig({
  server: {
    hmr: {
      host: "localhost",
    },
    watch: {
      usePolling: false, // uses a sh*tton of CPU
    },
  },
  build: {
    rollupOptions: {
      output: {
        codeSplitting: { groups: chunkGroups },
      },
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
});
