import { defineConfig } from "blume";

interface ThemeMetadata {
  value: string;
  color_scheme: "dark" | "light";
  preview: {
    darker: string;
    primary: string;
    content: string;
  };
  docs: {
    muted: string;
    muted_foreground: string;
    border: string;
    accent_foreground: string;
    code_background: string;
  };
}

interface BunRuntime {
  file(path: URL): { text(): Promise<string> };
  YAML: { parse(source: string): unknown };
}

const bun = (globalThis as typeof globalThis & { Bun: BunRuntime }).Bun;
const themes = bun.YAML.parse(
  await bun.file(new URL("./config/themes.yml", import.meta.url)).text(),
) as ThemeMetadata[];
const docsThemes = Object.fromEntries(
  themes.map((theme) => [
    theme.value,
    {
      colorScheme: theme.color_scheme,
      tokens: {
        "--blume-background": theme.preview.darker,
        "--blume-foreground": theme.preview.content,
        "--blume-muted": theme.docs.muted,
        "--blume-muted-foreground": theme.docs.muted_foreground,
        "--blume-border": theme.docs.border,
        "--blume-accent": theme.preview.primary,
        "--blume-accent-foreground": theme.docs.accent_foreground,
        "--blume-action": theme.preview.primary,
        "--blume-action-foreground": theme.docs.accent_foreground,
        "--blume-code-background": theme.docs.code_background,
      },
    },
  ]),
);

const themeScript = `(() => {
  const themes = ${JSON.stringify(docsThemes)};
  const cookie = document.cookie
    .split("; ")
    .find((entry) => entry.startsWith("hackatime_theme="));
  const selected = cookie
    ? cookie.slice("hackatime_theme=".length)
    : "neon";
  const theme = Object.hasOwn(themes, selected) ? selected : "neon";
  const { colorScheme, tokens } = themes[theme];

  document.documentElement.dataset.hackatimeTheme = theme;
  document.documentElement.dataset.theme = colorScheme;
  for (const [property, value] of Object.entries(tokens)) {
    document.documentElement.style.setProperty(property, value);
  }
  try {
    localStorage.setItem("blume-theme", colorScheme);
  } catch {}
})();`;

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
  integrations: [
    {
      name: "hackatime-docs-theme",
      hooks: {
        "astro:config:setup": ({ injectScript }) => {
          injectScript("head-inline", themeScript);
        },
      },
    },
  ],
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
