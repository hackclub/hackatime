import { type CreateInertiaAppOptions, type CreateInertiaAppOptionsForCSR, type InertiaAppSSRResponse, type Page, type PageProps } from '@inertiajs/core';
import App, { type InertiaAppProps } from './components/App.svelte';
import type { ComponentResolver, SvelteInertiaAppConfig } from './types';
type SvelteRenderResult = {
    body: string;
    head: string;
};
type SetupOptions<SharedProps extends PageProps> = {
    el: HTMLElement | null;
    App: typeof App;
    props: InertiaAppProps<SharedProps>;
};
type InertiaAppOptionsForCSR<SharedProps extends PageProps> = CreateInertiaAppOptionsForCSR<SharedProps, ComponentResolver, SetupOptions<SharedProps>, SvelteRenderResult | void, SvelteInertiaAppConfig>;
type InertiaAppOptionsAuto<SharedProps extends PageProps> = CreateInertiaAppOptions<ComponentResolver, SetupOptions<SharedProps>, SvelteRenderResult | void, SvelteInertiaAppConfig> & {
    page?: Page<SharedProps>;
};
type SvelteServerRender = (component: typeof App, options: {
    props: InertiaAppProps<PageProps>;
}) => SvelteRenderResult;
type RenderFunction<SharedProps extends PageProps> = (page: Page<SharedProps>, render: SvelteServerRender) => Promise<InertiaAppSSRResponse>;
export default function createInertiaApp<SharedProps extends PageProps = PageProps>(options: InertiaAppOptionsForCSR<SharedProps>): Promise<InertiaAppSSRResponse | void>;
export default function createInertiaApp<SharedProps extends PageProps = PageProps>(options?: InertiaAppOptionsAuto<SharedProps>): Promise<void | RenderFunction<SharedProps>>;
export {};
