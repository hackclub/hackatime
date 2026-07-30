import { defineConfig } from "blume";

export default defineConfig({
  title: "Hackatime Docs",
  description:
    "Learn how to set up Hackatime, track your coding time, and build integrations.",
  basePath: "/docs",
  logo: {
    image: "/images/new-icon-rounded.png",
    text: "Hackatime",
    href: "/docs",
  },
  github: {
    owner: "hackclub",
    repo: "hackatime",
  },
  navigation: {
    sidebar: {
      display: "page",
    },
  },
  theme: {
    accent: "#d7ff6a",
    action: "#d7ff6a",
    background: "#101312",
    mode: "dark",
    radius: "lg",
  },
  deployment: {
    output: "static",
    site: "https://hackatime.hackclub.com",
  },
  analytics: {
    scripts: [
      {
        content: `window.addEventListener("blume:track", (event) => {
          if (event.detail?.event !== "feedback") return;

          let visitorToken = localStorage.getItem("hackatime-docs-visitor");
          if (!visitorToken) {
            visitorToken = crypto.randomUUID();
            localStorage.setItem("hackatime-docs-visitor", visitorToken);
          }

          fetch("/docs/feedback", {
            method: "POST",
            credentials: "same-origin",
            keepalive: true,
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
              helpful: event.detail.props.helpful === "yes",
              path: event.detail.props.path,
              title: event.detail.props.title,
              visitor_token: visitorToken,
            }),
          }).catch(() => {});
        });`,
      },
    ],
  },
  seo: {
    og: { enabled: false },
    rss: { enabled: false },
    sitemap: false,
    robots: false,
    structuredData: true,
  },
});
