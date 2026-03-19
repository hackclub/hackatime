import { type CreateInertiaAppOptionsForCSR, type InertiaAppResponse, type PageProps, type SharedPageProps } from '@inertiajs/core';
import App, { type InertiaAppProps } from './components/App.svelte';
import type { ComponentResolver, SvelteInertiaAppConfig } from './types';
type SvelteRenderResult = {
    html: string;
    head: string;
    css?: {
        code: string;
    };
};
type SetupOptions<SharedProps extends PageProps> = {
    el: HTMLElement | null;
    App: typeof App;
    props: InertiaAppProps<SharedProps>;
};
type InertiaAppOptions<SharedProps extends PageProps> = CreateInertiaAppOptionsForCSR<SharedProps, ComponentResolver, SetupOptions<SharedProps>, SvelteRenderResult | void, SvelteInertiaAppConfig>;
export default function createInertiaApp<SharedProps extends PageProps = PageProps & SharedPageProps>({ id, resolve, setup, progress, page, defaults, }: InertiaAppOptions<SharedProps>): InertiaAppResponse;
export {};
