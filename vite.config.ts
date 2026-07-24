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
    allowedHosts: portal ? true : undefined,
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
    {
      name: "portal-resolved-url",
      configureServer(server) {
        if (!publicUrl) return;

        server.httpServer?.on("listening", () => {
          if (server.resolvedUrls) server.resolvedUrls.local = [publicUrl];
        });
      },
    },
    inertia({
      ssr: "ssr/ssr.ts",
    }),
    svelte(),
    tailwindcss(),
    RubyPlugin(),
  ],
});
