import { createInertiaApp, type ResolvedComponent } from "@inertiajs/svelte";
import { compileSheet } from "beasties/compiler";
import { createProcessor } from "beasties/runtime";
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
const stylesheetFiles = [
  ...new Set(
    Object.values(manifest).flatMap(({ file, css = [] }) => [
      ...(file.endsWith(".css") ? [file] : []),
      ...css,
    ]),
  ),
];
const stylesheet = stylesheetFiles
  .map((file) => readFileSync(join(vitePublicDir, file), "utf8"))
  .join("\n");
const criticalCss = createProcessor(
  [
    compileSheet(stylesheet, {
      href: `${viteBase}assets/`,
      allowRules: [/\.space-y-/],
    }),
  ],
  { inlineFonts: true, preloadFonts: true },
);

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
    const document = `<html data-theme="${escapeAttribute(layout.theme.name)}" data-color-scheme="${escapeAttribute(layout.theme.color_scheme)}"><body class="flex min-h-screen bg-darker">${body}</body></html>`;
    const critical = criticalCss.extract(document);
    const fontPreloads = critical.fontPreloads
      .map(
        (href) =>
          `<link rel="preload" href="${escapeAttribute(href)}" as="font" crossorigin>`,
      )
      .join("");
    const nonce = layout.csp_nonce
      ? ` nonce="${escapeAttribute(layout.csp_nonce)}"`
      : "";

    return {
      body,
      head: `${rendered.head}${fontPreloads}<style data-initial-vite-stylesheet="critical"${nonce}>${critical.css}</style>`,
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
