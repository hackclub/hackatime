import { RequestParams } from './requestParams';
import { ActiveVisit, ErrorBag, Errors, HttpResponse, Page } from './types';
export declare class Response {
    protected requestParams: RequestParams;
    protected response: HttpResponse;
    protected originatingPage: Page;
    protected wasPrefetched: boolean;
    constructor(requestParams: RequestParams, response: HttpResponse, originatingPage: Page);
    static create(params: RequestParams, response: HttpResponse, originatingPage: Page): Response;
    handlePrefetch(): Promise<void>;
    handle(): Promise<void>;
    process(): Promise<boolean | void>;
    mergeParams(params: ActiveVisit): void;
    getPageResponse(): Page;
    protected handleNonInertiaResponse(): Promise<boolean | void>;
    protected isInertiaResponse(): boolean;
    protected hasStatus(status: number): boolean;
    protected getHeader(header: string): string;
    protected hasHeader(header: string): boolean;
    protected isLocationVisit(): boolean;
    /**
     * @link https://inertiajs.com/redirects#external-redirects
     */
    protected locationVisit(url: URL): boolean | void;
    protected setPage(): Promise<void>;
    protected getDataFromResponse(response: any): any;
    protected shouldSetPage(pageResponse: Page): boolean;
    protected pageUrl(pageResponse: Page): string;
    protected preserveEqualProps(pageResponse: Page): void;
    protected mergeProps(pageResponse: Page): void;
    /**
     * By default, the Laravel adapter shares validation errors via Inertia::always(),
     * so responses always include errors, even when empty. Components like
     * InfiniteScroll and WhenVisible, as well as loading deferred props,
     * perform async requests that should practically never reset errors.
     */
    protected shouldPreserveErrors(pageResponse: Page): boolean;
    protected mergeOrMatchItems(existingItems: any[], newItems: any[], matchProp: string, matchPropsOn: string[], shouldAppend?: boolean): any[];
    protected appendWithMatching(existingItems: any[], newItems: any[], newItemsMap: Map<any, any>, uniqueProperty: string): any[];
    protected prependWithMatching(existingItems: any[], newItems: any[], newItemsMap: Map<any, any>, uniqueProperty: string): any[];
    protected hasUniqueProperty(item: any, property: string): boolean;
    protected setRememberedState(pageResponse: Page): Promise<void>;
    protected getScopedErrors(errors: Errors & ErrorBag): Errors;
}
