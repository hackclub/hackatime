import "@fontsource-variable/spline-sans";
import { createInertiaApp } from "@inertiajs/svelte";
import { inertiaDefaults, resolvePage } from "../inertia";

createInertiaApp({
  resolve: resolvePage,
  defaults: inertiaDefaults,
  progress: {
    color: "var(--color-primary)",
  },
});
