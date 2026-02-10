import { createInertiaApp, type ResolvedComponent } from '@inertiajs/svelte'
import createServer from '@inertiajs/svelte/server'
import { render } from 'svelte/server'
import AppLayout from '../layouts/AppLayout.svelte'

createServer((page) =>
  createInertiaApp({
    page,
    resolve: (name) => {
      const pages = import.meta.glob<ResolvedComponent>('../pages/**/*.svelte', {
        eager: true,
      })
      const page = pages[`../pages/${name}.svelte`]
      if (!page) {
        console.error(`Missing Inertia page component: '${name}.svelte'`)
      }

      return { default: page.default, layout: page.layout || AppLayout } as ResolvedComponent
    },
    setup({ App, props }) {
      return render(App, { props })
    },
    defaults: {
      future: {
        useScriptElementForInitialPage: true,
        useDataInertiaHeadAttribute: true,
      },
    },
  }),
)
