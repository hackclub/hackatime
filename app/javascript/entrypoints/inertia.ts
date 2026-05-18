import "@fontsource-variable/spline-sans";
import {
  createInertiaApp,
  router,
  type ResolvedComponent,
} from "@inertiajs/svelte";
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
      return [
        "WakatimeSetup/Index",
        "Projects/Index",
        "Leaderboards/Index",
        "Profiles/Show",
      ];
    case "Projects/Index":
      return ["Home/SignedIn", "Leaderboards/Index", "Projects/Show"];
    case "Projects/Show":
      return ["Projects/Index", "Home/SignedIn"];
    case "Leaderboards/Index":
      return ["Home/SignedIn", "Projects/Index", "Profiles/Show"];
    case "Profiles/Show":
      return ["Home/SignedIn", "Leaderboards/Index"];
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

function prefetchLikelyNextPages(pageName: string | null) {
  likelyNextPages(pageName).forEach(prefetchPage);
}

function schedulePrefetch(pageName: string | null) {
  if (typeof window === "undefined") return;

  const run = () => prefetchLikelyNextPages(pageName);

  if ("requestIdleCallback" in window) {
    window.requestIdleCallback(run, { timeout: 1500 });
    return;
  }

  globalThis.setTimeout(run, 400);
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

schedulePrefetch(currentPageName());

if (typeof window !== "undefined") {
  router.on("success", (event) => {
    const page = event.detail?.page;
    const component =
      typeof page?.component === "string" ? page.component : null;
    schedulePrefetch(component);
  });
}
