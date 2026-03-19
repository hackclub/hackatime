import { type InfiniteScrollComponentBaseProps } from '@inertiajs/core';
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
declare const InfiniteScroll: $$__sveltets_2_IsomorphicComponent<$$__sveltets_2_PropsWithChildren<{
    [x: string]: any;
    data: InfiniteScrollComponentBaseProps["data"];
    buffer?: InfiniteScrollComponentBaseProps["buffer"];
    as?: InfiniteScrollComponentBaseProps["as"];
    manual?: InfiniteScrollComponentBaseProps["manual"];
    manualAfter?: InfiniteScrollComponentBaseProps["manualAfter"];
    preserveUrl?: InfiniteScrollComponentBaseProps["preserveUrl"];
    reverse?: InfiniteScrollComponentBaseProps["reverse"];
    autoScroll?: InfiniteScrollComponentBaseProps["autoScroll"];
    startElement?: string | (() => HTMLElement | null) | null | undefined;
    endElement?: string | (() => HTMLElement | null) | null | undefined;
    itemsElement?: string | (() => HTMLElement | null) | null | undefined;
    onlyNext?: boolean | undefined;
    onlyPrevious?: boolean | undefined;
    fetchPrevious?: ((options?: any) => void) | undefined;
    fetchNext?: ((options?: any) => void) | undefined;
    hasPrevious?: (() => boolean) | undefined;
    hasNext?: (() => boolean) | undefined;
}, {
    previous: any;
    loading: any;
    next: any;
    default: any;
}>, {
    [evt: string]: CustomEvent<any>;
}, {
    previous: any;
    loading: any;
    next: any;
    default: any;
}, {
    fetchPrevious: (options?: any) => void;
    fetchNext: (options?: any) => void;
    hasPrevious: () => boolean;
    hasNext: () => boolean;
}, string>;
type InfiniteScroll = InstanceType<typeof InfiniteScroll>;
export default InfiniteScroll;
