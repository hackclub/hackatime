import { type VisitOptions } from '@inertiajs/core';
export default function usePrefetch(options?: VisitOptions): {
    readonly isPrefetched: boolean;
    readonly isPrefetching: boolean;
    readonly lastUpdatedAt: number | null;
    flush(): void;
};
