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
      const pageComponent = pages[`../pages/${name}.svelte`]
      if (!pageComponent) {
        console.error(`Missing Inertia page component: '${name}.svelte'`)
      }

      return {
        default: pageComponent.default,
        layout: pageComponent.layout || AppLayout,
      } as ResolvedComponent
    },

    setup({ App, props }) {
      return render(App, { props })
    },

    defaults: {
      form: {
        forceIndicesArrayFormatInFormData: false,
      },
      future: {
        useScriptElementForInitialPage: true,
        useDataInertiaHeadAttribute: true,
        useDialogForErrorModal: true,
        preserveEqualProps: true,
      },
    },
  }),
)
