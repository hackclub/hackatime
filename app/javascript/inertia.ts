import type { CreateInertiaAppOptions } from "@inertiajs/core";
import type { ResolvedComponent } from "@inertiajs/svelte";
import AppLayout from "./layouts/AppLayout.svelte";

const pages = import.meta.glob<ResolvedComponent>("./pages/**/*.svelte");

export const inertiaDefaults: NonNullable<
  CreateInertiaAppOptions["defaults"]
> = {
  form: {
    forceIndicesArrayFormatInFormData: false,
  },
};

export async function resolvePage(name: string): Promise<ResolvedComponent> {
  const loadPage = pages[`./pages/${name}.svelte`];

  if (!loadPage) {
    throw new Error(`Missing Inertia page component: '${name}.svelte'`);
  }

  const component = await loadPage();
  const layout =
    component.layout === false ? undefined : component.layout || AppLayout;

  return {
    default: component.default,
    layout,
  };
}
