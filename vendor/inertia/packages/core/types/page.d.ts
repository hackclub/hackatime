import { Component, FlashData, Page, PageEvent, PageHandler, PageResolver, RouterInitParams, Visit } from './types';
declare class CurrentPage {
    protected page: Page;
    protected swapComponent: PageHandler<any>;
    protected resolveComponent: PageResolver;
    protected onFlashCallback?: (flash: Page['flash']) => void;
    protected componentId: {};
    protected listeners: {
        event: PageEvent;
        callback: VoidFunction;
    }[];
    protected isFirstPageLoad: boolean;
    protected cleared: boolean;
    protected pendingDeferredProps: Pick<Page, 'deferredProps' | 'url' | 'component'> | null;
    protected historyQuotaExceeded: boolean;
    init<ComponentType = Component>({ initialPage, swapComponent, resolveComponent, onFlash, }: RouterInitParams<ComponentType>): this;
    set(page: Page, { replace, preserveScroll, preserveState, viewTransition, }?: {
        replace?: boolean;
        preserveScroll?: boolean;
        preserveState?: boolean;
        viewTransition?: Visit['viewTransition'];
    }): Promise<void>;
    setQuietly(page: Page, { preserveState, }?: {
        preserveState?: boolean;
    }): Promise<unknown>;
    clear(): void;
    isCleared(): boolean;
    get(): Page;
    getWithoutFlashData(): Page;
    hasOnceProps(): boolean;
    merge(data: Partial<Page>): void;
    setPropsQuietly(props: Page['props']): Promise<unknown>;
    setFlash(flash: FlashData): void;
    setUrlHash(hash: string): void;
    remember(data: Page['rememberedState']): void;
    swap({ component, page, preserveState, viewTransition, }: {
        component: Component;
        page: Page;
        preserveState: boolean;
        viewTransition: Visit['viewTransition'];
    }): Promise<unknown>;
    resolve(component: string, page?: Page): Promise<Component>;
    isTheSame(page: Page): boolean;
    on(event: PageEvent, callback: VoidFunction): VoidFunction;
    fireEventsFor(event: PageEvent): void;
    mergeOncePropsIntoResponse(response: Page, { force }?: {
        force?: boolean;
    }): void;
}
export declare const page: CurrentPage;
export {};
