import "@fontsource-variable/spline-sans";
import { createInertiaApp } from "@inertiajs/svelte";
import AppLayout from "../layouts/AppLayout.svelte";

createInertiaApp({
  progress: {
    color: "var(--color-primary)",
  },

  pages: {
    path: "../pages",
    lazy: false,
  },

  layout: () => AppLayout,

  defaults: {
    form: {
      forceIndicesArrayFormatInFormData: false,
    },
  },
});
