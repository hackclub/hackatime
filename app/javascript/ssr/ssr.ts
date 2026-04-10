import "@fontsource-variable/spline-sans";
import { createInertiaApp } from "@inertiajs/svelte";
import AppLayout from "../layouts/AppLayout.svelte";

createInertiaApp({
  pages: {
    path: "../pages",
    lazy: false,
  },
  layout: () => AppLayout,
});
