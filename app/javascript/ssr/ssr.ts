import "@fontsource-variable/spline-sans";
import { createInertiaApp, type ResolvedComponent } from "@inertiajs/svelte";
import createServer from "@inertiajs/svelte/server";
import { render } from "svelte/server";
import AppLayout from "../layouts/AppLayout.svelte";

type PageModule = {
  default: ResolvedComponent["default"];
  layout?: ResolvedComponent["layout"] | false;
};

const pages = import.meta.glob<PageModule>("../pages/**/*.svelte", {
  eager: true,
});

createServer((page) =>
  createInertiaApp({
    page,
    resolve: (name) => {
      const component = pages[`../pages/${name}.svelte`];
      if (!component) {
        throw new Error(`Missing Inertia page component: '${name}.svelte'`);
      }

      const layout =
        component.layout === false ? undefined : component.layout || AppLayout;
      return { default: component.default, layout } as ResolvedComponent;
    },
    setup({ App, props }) {
      return render(App, { props });
    },
  }),
);
