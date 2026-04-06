import { buildSSRBody, getInitialPageFromDOM, http as httpModule, router, setupProgress, } from '@inertiajs/core';
import { hydrate, mount } from 'svelte';
import App, {} from './components/App.svelte';
import { config } from './index';
export default async function createInertiaApp({ id = 'app', resolve, setup, progress = {}, page, defaults = {}, http, layout, } = {}) {
    config.replace(defaults);
    if (http) {
        httpModule.setClient(http);
    }
    const isServer = typeof window === 'undefined';
    const resolveComponent = (name, page) => Promise.resolve(resolve(name, page));
    if (isServer && !page) {
        return async (page, render) => {
            const initialComponent = (await resolveComponent(page.component, page));
            const props = {
                initialPage: page,
                initialComponent,
                resolveComponent,
                defaultLayout: layout,
            };
            let svelteApp;
            if (setup) {
                const result = await setup({ el: null, App, props });
                if (!result) {
                    throw new Error('Inertia SSR setup function must return a render result ({ body, head })');
                }
                svelteApp = result;
            }
            else {
                svelteApp = render(App, { props });
            }
            const body = buildSSRBody(id, page, svelteApp.body);
            return {
                body,
                head: [svelteApp.head],
            };
        };
    }
    const initialPage = page || getInitialPageFromDOM(id);
    const [initialComponent] = await Promise.all([
        resolveComponent(initialPage.component, initialPage),
        router.decryptHistory().catch(() => { }),
    ]);
    const props = { initialPage, initialComponent, resolveComponent, defaultLayout: layout };
    if (isServer) {
        if (!setup) {
            throw new Error('Inertia SSR requires a setup function that returns a render result ({ body, head })');
        }
        const svelteApp = await setup({ el: null, App, props });
        if (svelteApp) {
            const body = buildSSRBody(id, initialPage, svelteApp.body);
            return {
                body,
                head: [svelteApp.head],
            };
        }
        return;
    }
    const target = document.getElementById(id);
    if (setup) {
        await setup({ el: target, App, props });
    }
    else if (target.hasAttribute('data-server-rendered')) {
        hydrate(App, { target, props });
    }
    else {
        mount(App, { target, props });
    }
    if (progress) {
        setupProgress(progress);
    }
}
