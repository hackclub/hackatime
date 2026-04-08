import "@fontsource-variable/spline-sans";
import { createInertiaApp } from "@inertiajs/svelte";
import { inertiaDefaults, resolvePage } from "../inertia";

createInertiaApp({
  page: undefined,
  resolve: resolvePage,
  defaults: inertiaDefaults,
  setup({ App, props }) {
    return render(App, { props });
  },
});
