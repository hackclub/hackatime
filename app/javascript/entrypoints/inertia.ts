import "@fontsource-variable/spline-sans";
import { createInertiaApp, type ResolvedComponent } from "@inertiajs/svelte";
import AppLayout from "../layouts/AppLayout.svelte";

createInertiaApp({
  // Disable progress bar
  //
  // see https://inertia-rails.dev/guide/progress-indicators
  // progress: false,

  resolve: (name) => {
    const pages = import.meta.glob<ResolvedComponent>("../pages/**/*.svelte", {
      eager: true,
    });
    const page = pages[`../pages/${name}.svelte`];
    if (!page) {
      console.error(`Missing Inertia page component: '${name}.svelte'`);
    }

    const layout = page.layout === false ? undefined : page.layout || AppLayout;
    return { default: page.default, layout } as ResolvedComponent;
  },

  defaults: {
    form: {
      forceIndicesArrayFormatInFormData: false,
    },
  },
});
