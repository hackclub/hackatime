import { type VisitOptions } from '@inertiajs/core';
export default function usePrefetch(options?: VisitOptions): {
    isPrefetched: import("svelte/store").Readable<boolean>;
    isPrefetching: import("svelte/store").Readable<boolean>;
    lastUpdatedAt: import("svelte/store").Readable<number | null>;
    flush(): void;
};
