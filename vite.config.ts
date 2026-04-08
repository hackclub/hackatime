import inertia from "@inertiajs/vite";
import { svelte } from "@sveltejs/vite-plugin-svelte";
import tailwindcss from "@tailwindcss/vite";
import { defineConfig } from "vite";
import RubyPlugin from "vite-plugin-ruby";

export default defineConfig({
  server: {
    hmr: {
      host: "localhost",
    },
  },
  plugins: [
    inertia({
      ssr: {
        entry: "ssr/ssr.ts",
      },
    }),
    svelte(),
    tailwindcss(),
    RubyPlugin(),
  ],
});
