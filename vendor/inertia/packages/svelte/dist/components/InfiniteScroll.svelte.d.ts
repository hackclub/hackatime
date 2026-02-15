import { type InfiniteScrollComponentBaseProps, type ReloadOptions } from '@inertiajs/core';
interface Props {
    data: InfiniteScrollComponentBaseProps['data'];
    buffer?: InfiniteScrollComponentBaseProps['buffer'];
    as?: InfiniteScrollComponentBaseProps['as'];
    manual?: InfiniteScrollComponentBaseProps['manual'];
    manualAfter?: InfiniteScrollComponentBaseProps['manualAfter'];
    preserveUrl?: InfiniteScrollComponentBaseProps['preserveUrl'];
    reverse?: InfiniteScrollComponentBaseProps['reverse'];
    autoScroll?: InfiniteScrollComponentBaseProps['autoScroll'];
    startElement?: string | (() => HTMLElement | null) | null;
    endElement?: string | (() => HTMLElement | null) | null;
    itemsElement?: string | (() => HTMLElement | null) | null;
    params?: ReloadOptions;
    onlyNext?: boolean;
    onlyPrevious?: boolean;
    previous?: import('svelte').Snippet<[any]>;
    loading?: import('svelte').Snippet<[any]>;
    next?: import('svelte').Snippet<[any]>;
    children?: import('svelte').Snippet<[any]>;
    [key: string]: any;
}
declare const InfiniteScroll: import("svelte").Component<Props, {
    fetchPrevious: (options?: any) => void;
    fetchNext: (options?: any) => void;
    hasPrevious: () => boolean;
    hasNext: () => boolean;
}, "">;
type InfiniteScroll = ReturnType<typeof InfiniteScroll>;
export default InfiniteScroll;
