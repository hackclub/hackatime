import "@fontsource-variable/spline-sans";
import { createInertiaApp, type ResolvedComponent } from "@inertiajs/svelte";
import AppLayout from "../layouts/AppLayout.svelte";

const pages = import.meta.glob<ResolvedComponent>("../pages/**/*.svelte");

const prefetchedPages = new Set<string>();

function currentPageName(): string | null {
  if (typeof document === "undefined") return null;

  const node = document.querySelector<HTMLScriptElement>(
    '#app > script[type="application/json"]',
  );
  const raw = node?.textContent;
  if (!raw) return null;

  try {
    const page = JSON.parse(raw) as { component?: string };
    return typeof page.component === "string" ? page.component : null;
  } catch {
    return null;
  }
}

function likelyNextPages(pageName: string | null): string[] {
  switch (pageName) {
    case "Home/SignedOut":
    case "Auth/SignIn":
      return ["Home/SignedIn"];
    case "Home/SignedIn":
      return ["WakatimeSetup/Index"];
    default:
      return [];
  }
}

function prefetchPage(name: string) {
  const pagePath = `../pages/${name}.svelte`;
  const loadPage = pages[pagePath];
  if (!loadPage || prefetchedPages.has(pagePath)) return;

  prefetchedPages.add(pagePath);
  void loadPage().catch((error) => {
    prefetchedPages.delete(pagePath);
    console.debug(
      `Failed to prefetch Inertia page component: '${name}.svelte'`,
      error,
    );
  });
}

function prefetchLikelyNextPages() {
  likelyNextPages(currentPageName()).forEach(prefetchPage);
}

function schedulePrefetch() {
  if (typeof window === "undefined") return;

  if ("requestIdleCallback" in window) {
    window.requestIdleCallback(prefetchLikelyNextPages, { timeout: 1500 });
    return;
  }

  globalThis.setTimeout(prefetchLikelyNextPages, 400);
}

createInertiaApp({
  // see https://inertia-rails.dev/guide/progress-indicators
  progress: {
    color: "var(--color-primary)",
  },

  layout: () => AppLayout,

  resolve: async (name) => {
    const loadPage = pages[`../pages/${name}.svelte`];
    if (!loadPage) {
      throw new Error(`Missing Inertia page component: '${name}.svelte'`);
    }
    return await loadPage();
  },

  defaults: {
    form: {
      forceIndicesArrayFormatInFormData: false,
    },
  },
});

schedulePrefetch();
