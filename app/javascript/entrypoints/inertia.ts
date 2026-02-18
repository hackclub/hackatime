import "@fontsource-variable/spline-sans";
import { createInertiaApp, type ResolvedComponent } from "@inertiajs/svelte";
import AppLayout from "../layouts/AppLayout.svelte";

const pages = import.meta.glob<ResolvedComponent>("../pages/**/*.svelte", {
  eager: true,
});

createInertiaApp({
  // Disable progress bar
  //
  // see https://inertia-rails.dev/guide/progress-indicators
  // progress: false,

  resolve: (name) => {
    const component = pages[`../pages/${name}.svelte`];
    if (!component) {
      console.error(`Missing Inertia page component: '${name}.svelte'`);
    }

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
