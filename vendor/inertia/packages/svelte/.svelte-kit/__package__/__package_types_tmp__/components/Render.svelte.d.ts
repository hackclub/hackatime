import type { PageProps } from '@inertiajs/core';
import type { ComponentType } from 'svelte';
export type RenderProps = {
    component: ComponentType;
    props?: PageProps;
    children?: RenderProps[];
    key?: number | null;
};
export type RenderFunction = {
    (component: ComponentType, props?: PageProps, children?: RenderProps[], key?: number | null): RenderProps;
    (component: ComponentType, children?: RenderProps[], key?: number | null): RenderProps;
};
export declare const h: RenderFunction;
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
declare const Render: $$__sveltets_2_IsomorphicComponent<{
    component: ComponentType;
    props?: PageProps;
    children?: RenderProps[];
    key?: number | null;
}, {
    [evt: string]: CustomEvent<any>;
}, {}, {}, string>;
type Render = InstanceType<typeof Render>;
export default Render;
