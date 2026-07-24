import inertia from "@inertiajs/vite";
import { svelte } from "@sveltejs/vite-plugin-svelte";
import tailwindcss from "@tailwindcss/vite";
import { defineConfig } from "vite";
import RubyPlugin from "vite-plugin-ruby";

const publicUrl = process.env.PUBLIC_URL?.replace(/\/$/, "");
const portal = publicUrl ? new URL(publicUrl) : null;

export default defineConfig({
  server: {
    origin: publicUrl,
    allowedHosts: portal ? [portal.hostname] : undefined,
    hmr: portal
      ? {
          protocol: portal.protocol === "https:" ? "wss" : "ws",
          host: portal.hostname,
          clientPort: portal.protocol === "https:" ? 443 : Number(portal.port),
        }
      : {
          host: "localhost",
        },
    proxy: portal
      ? {
          "^/(?!vite-dev(?:/|$))": "http://localhost:3000",
        }
      : undefined,
    watch: {
      usePolling: false, // uses a sh*tton of CPU
    },
  },
  plugins: [
    inertia({
      ssr: portal ? false : "ssr/ssr.ts",
    }),
    svelte(),
    tailwindcss(),
    RubyPlugin(),
  ],
});
