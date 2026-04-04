import "@fontsource-variable/spline-sans";
import { createInertiaApp } from "@inertiajs/svelte";
import createServer from "@inertiajs/svelte/server";
import AppLayout from "../layouts/AppLayout.svelte";

createServer((page) =>
  createInertiaApp({
    page,
    pages: '../pages',
    layout: () => AppLayout,
  }),
);
