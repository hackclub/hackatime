import type { ComponentResolver, ResolvedComponent } from '../types';
import { type Page, type PageProps } from '@inertiajs/core';
export interface InertiaAppProps<SharedProps extends PageProps = PageProps> {
    initialComponent: ResolvedComponent;
    initialPage: Page<SharedProps>;
    resolveComponent: ComponentResolver;
}
interface $$__sveltets_2_IsomorphicComponent<Props extends Record<string, any> = any, Events extends Record<string, any> = any, Slots extends Record<string, any> = any, Exports = {}, Bindings = string> {
    new (options: import('svelte').ComponentConstructorOptions<Props>): import('svelte').SvelteComponent<Props, Events, Slots> & {
        $$bindings?: Bindings;
    } & Exports;
    (internal: unknown, props: Props & {
        $$events?: Events;
        $$slots?: Slots;
    }): Exports & {
        $set?: any;
        $on?: any;
    };
    z_$$bindings?: Bindings;
}
declare const App: $$__sveltets_2_IsomorphicComponent<{
    initialComponent: InertiaAppProps["initialComponent"];
    initialPage: InertiaAppProps["initialPage"];
    resolveComponent: InertiaAppProps["resolveComponent"];
}, {
    [evt: string]: CustomEvent<any>;
}, {}, {}, string>;
type App = InstanceType<typeof App>;
export default App;
