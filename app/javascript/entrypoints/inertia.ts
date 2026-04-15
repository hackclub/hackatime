import "@fontsource-variable/spline-sans";
import { createInertiaApp, type ResolvedComponent } from "@inertiajs/svelte";
import AppLayout from "../layouts/AppLayout.svelte";

type InertiaPageModule = {
  default: ResolvedComponent["default"];
  layout?: ResolvedComponent["layout"] | false;
};

const pages = import.meta.glob<InertiaPageModule>("../pages/**/*.svelte");

const prefetchedPages = new Set<string>();

function prefetchPage(name: string) {
  const pagePath = `../pages/${name}.svelte`;
  const loadPage = pages[pagePath];
  if (!loadPage || prefetchedPages.has(pagePath)) return;

  prefetchedPages.add(pagePath);
  void loadPage();
}

function prefetchLikelyNextPages() {
  ["WakatimeSetup/Index", "Home/SignedIn"].forEach(prefetchPage);
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

  resolve: async (name) => {
    const loadPage = pages[`../pages/${name}.svelte`];
    if (!loadPage) {
      console.error(`Missing Inertia page component: '${name}.svelte'`);
      throw new Error(`Missing Inertia page component: '${name}.svelte'`);
    }

    const component = await loadPage();

    const layout =
      component.layout === false ? undefined : component.layout || AppLayout;
    return { default: component.default, layout } as ResolvedComponent;
  },

  defaults: {
    form: {
      forceIndicesArrayFormatInFormData: false,
    },
  },
});

schedulePrefetch();
