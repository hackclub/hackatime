import { type ReloadOptions } from '@inertiajs/core';
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
type $$__sveltets_2_PropsWithChildren<Props, Slots> = Props & (Slots extends {
    default: any;
} ? Props extends Record<string, never> ? any : {
    children?: any;
} : {});
declare const WhenVisible: $$__sveltets_2_IsomorphicComponent<$$__sveltets_2_PropsWithChildren<{
    data?: string | string[];
    params?: ReloadOptions;
    buffer?: number;
    as?: keyof HTMLElementTagNameMap;
    always?: boolean;
}, {
    default: {
        fetching: boolean;
    };
    fallback: {};
}>, {
    [evt: string]: CustomEvent<any>;
}, {
    default: {
        fetching: boolean;
    };
    fallback: {};
}, {}, string>;
type WhenVisible = InstanceType<typeof WhenVisible>;
export default WhenVisible;
