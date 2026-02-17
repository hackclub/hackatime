import { Response } from './response';
import { ActiveVisit, CacheForOption, InFlightPrefetch, InternalActiveVisit, Page, PrefetchedResponse, PrefetchOptions, PrefetchRemovalTimer } from './types';
declare class PrefetchedRequests {
    protected cached: PrefetchedResponse[];
    protected inFlightRequests: InFlightPrefetch[];
    protected removalTimers: PrefetchRemovalTimer[];
    protected currentUseId: string | null;
    add(params: ActiveVisit, sendFunc: (params: InternalActiveVisit) => void, { cacheFor, cacheTags }: PrefetchOptions): Promise<void> | Promise<Response>;
    removeAll(): void;
    removeByTags(tags: string[]): void;
    remove(params: ActiveVisit): void;
    protected removeFromInFlight(params: ActiveVisit): void;
    protected extractStaleValues(cacheFor: PrefetchOptions['cacheFor']): [number, number];
    protected cacheForToStaleAndExpires(cacheFor: PrefetchOptions['cacheFor']): [CacheForOption, CacheForOption];
    protected clearTimer(params: ActiveVisit): void;
    protected scheduleForRemoval(params: ActiveVisit, expiresIn: number): void;
    get(params: ActiveVisit): InFlightPrefetch | PrefetchedResponse | null;
    use(prefetched: PrefetchedResponse | InFlightPrefetch, params: ActiveVisit): Promise<void | undefined>;
    protected removeSingleUseItems(params: ActiveVisit): void;
    findCached(params: ActiveVisit): PrefetchedResponse | null;
    findInFlight(params: ActiveVisit): InFlightPrefetch | null;
    protected withoutPurposePrefetchHeader(params: ActiveVisit): ActiveVisit;
    protected paramsAreEqual(params1: ActiveVisit, params2: ActiveVisit): boolean;
    updateCachedOncePropsFromCurrentPage(): void;
    protected getShortestOncePropTtl(page: Page): number | null;
}
export declare const prefetchedRequests: PrefetchedRequests;
export {};
