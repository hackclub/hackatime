import "@fontsource-variable/spline-sans";
import { createInertiaApp, type ResolvedComponent } from "@inertiajs/svelte";

const pages = import.meta.glob<ResolvedComponent>("../pages/**/*.svelte");

createInertiaApp({
  resolve: async (name) => {
    const loadPage = pages[`../pages/${name}.svelte`];
    if (!loadPage) {
      throw new Error(`Missing Inertia page component: '${name}.svelte'`);
    }
    const component = await loadPage();
    if (component.layout !== undefined) return component;

    const { default: AppLayout } = await import("../layouts/AppLayout.svelte");
    return { ...component, layout: AppLayout };
  },
});
