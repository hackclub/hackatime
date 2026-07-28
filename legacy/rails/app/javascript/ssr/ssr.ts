import "@fontsource-variable/spline-sans";
import { createInertiaApp, type ResolvedComponent } from "@inertiajs/svelte";
import AppLayout from "../layouts/AppLayout.svelte";

const pages = import.meta.glob<ResolvedComponent>("../pages/**/*.svelte", {
  eager: true,
});

createInertiaApp({
  layout: () => AppLayout,
  resolve: (name) => {
    const component = pages[`../pages/${name}.svelte`];
    if (!component) {
      throw new Error(`Missing Inertia page component: '${name}.svelte'`);
    }
    return component;
  },
});
