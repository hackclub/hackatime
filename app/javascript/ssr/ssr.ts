import "@fontsource-variable/spline-sans";
import { createInertiaApp, type ResolvedComponent } from "@inertiajs/svelte";
import AppLayout from "../layouts/AppLayout.svelte";

const pages = import.meta.glob<ResolvedComponent>("../pages/**/*.svelte");

createInertiaApp({
  layout: () => AppLayout,
  resolve: async (name) => {
    const loadPage = pages[`../pages/${name}.svelte`];
    if (!loadPage) {
      throw new Error(`Missing Inertia page component: '${name}.svelte'`);
    }
    return await loadPage();
  },
});
