import "@fontsource-variable/spline-sans";
import { createInertiaApp, type ResolvedComponent } from "@inertiajs/svelte";
import { compileSheet } from "beasties/compiler";
import { createProcessor, renderFullCss } from "beasties/runtime";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { render as renderSvelte } from "svelte/server";
import AppLayout from "../layouts/AppLayout.svelte";
import type { LayoutProps } from "../types";

type ManifestEntry = { file: string; css?: string[] };
type Manifest = Record<string, ManifestEntry>;

const viteBase = import.meta.env.BASE_URL;
const vitePublicDir = join(process.cwd(), "public", viteBase);
const manifest = JSON.parse(
  readFileSync(join(vitePublicDir, ".vite/manifest.json"), "utf8"),
) as Manifest;
const inertiaStylesheetFiles = manifest["entrypoints/inertia.ts"].css ?? [];
const stylesheetFiles = [
  ...new Set(
    Object.values(manifest).flatMap(({ file, css = [] }) => [
      ...(file.endsWith(".css") ? [file] : []),
      ...css,
    ]),
  ),
];
const stylesheets = new Map(
  stylesheetFiles.map((file) => [
    file,
    compileSheet(readFileSync(join(vitePublicDir, file), "utf8"), {
      href: `${viteBase}${file}`,
      allowRules: [/\.space-y-/],
    }),
  ]),
);
const criticalCss = createProcessor(
  [...stylesheets]
    .filter(([file]) => !inertiaStylesheetFiles.includes(file))
    .map(([, stylesheet]) => stylesheet),
  { inlineFonts: true, preloadFonts: false },
);
const inertiaCss = inertiaStylesheetFiles
  .map((file) => renderFullCss(stylesheets.get(file)!))
  .join("\n");

const escapeAttribute = (value: string) =>
  value.replaceAll("&", "&amp;").replaceAll('"', "&quot;");

const pages = import.meta.glob<ResolvedComponent>("../pages/**/*.svelte", {
  eager: true,
});

createInertiaApp({
  layout: () => AppLayout,
  setup: ({ App, props }) => {
    const rendered = renderSvelte(App, { props }) as {
      body?: string;
      html?: string;
      head: string;
    };
    const body = rendered.body ?? rendered.html ?? "";
    const layout = props.initialPage.props.layout as LayoutProps;
    const document = `<html class="fonts-pending" data-theme="${escapeAttribute(layout.theme.name)}" data-color-scheme="${escapeAttribute(layout.theme.color_scheme)}"><body class="flex min-h-screen bg-darker">${body}</body></html>`;
    const css = `${criticalCss.extract(document).css}\n${inertiaCss}`;
    const nonce = layout.csp_nonce
      ? ` nonce="${escapeAttribute(layout.csp_nonce)}"`
      : "";

    return {
      body,
      head: `${rendered.head}<style data-initial-vite-stylesheet="critical"${nonce}>${css}</style>`,
    };
  },
  resolve: (name) => {
    const component = pages[`../pages/${name}.svelte`];
    if (!component) {
      throw new Error(`Missing Inertia page component: '${name}.svelte'`);
    }
    return component;
  },
});
