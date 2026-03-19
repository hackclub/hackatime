import { type Page, type PageProps, type SharedPageProps } from '@inertiajs/core';
import { type Readable } from 'svelte/store';
type SveltePage<TPageProps extends PageProps = PageProps> = Omit<Page<TPageProps & SharedPageProps>, 'props'> & {
    props: Page<TPageProps & SharedPageProps>['props'] & {
        [key: string]: any;
    };
};
export declare const setPage: (this: void, value: SveltePage<PageProps>) => void;
declare const _default: {
    subscribe: (this: void, run: import("svelte/store").Subscriber<SveltePage<PageProps>>, invalidate?: () => void) => import("svelte/store").Unsubscriber;
};
export default _default;
export declare function usePage<TPageProps extends PageProps = PageProps>(): Readable<SveltePage<TPageProps>>;
