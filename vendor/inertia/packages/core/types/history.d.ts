import { Page, ScrollRegion } from './types';
declare class History {
    rememberedState: "rememberedState";
    scrollRegions: "scrollRegions";
    preserveUrl: boolean;
    protected current: Partial<Page>;
    protected initialState: Partial<Page> | null;
    remember(data: unknown, key: string): void;
    restore(key: string): unknown;
    pushState(page: Page, cb?: (() => void) | null): void;
    protected clonePageProps(page: Page): Page;
    protected getPageData(page: Page): Promise<Page | ArrayBuffer>;
    processQueue(): Promise<void>;
    decrypt(page?: Page | null): Promise<Page>;
    protected decryptPageData(pageData: ArrayBuffer | Page | null): Promise<Page | null>;
    saveScrollPositions(scrollRegions: ScrollRegion[]): void;
    saveDocumentScrollPosition(scrollRegion: ScrollRegion): void;
    getScrollRegions(): ScrollRegion[];
    getDocumentScrollPosition(): ScrollRegion;
    replaceState(page: Page, cb?: (() => void) | null): void;
    protected isHistoryThrottleError(error: unknown): error is Error & {
        name: 'SecurityError';
    };
    protected isQuotaExceededError(error: unknown): error is Error & {
        name: 'QuotaExceededError';
    };
    protected withThrottleProtection<T = void>(cb: () => T): Promise<T | undefined>;
    protected doReplaceState(data: {
        page: Page | ArrayBuffer;
        scrollRegions?: ScrollRegion[];
        documentScrollPosition?: ScrollRegion;
    }, url?: string): Promise<void>;
    protected doPushState(data: {
        page: Page | ArrayBuffer;
        scrollRegions?: ScrollRegion[];
        documentScrollPosition?: ScrollRegion;
    }, url: string): Promise<void>;
    getState<T>(key: keyof Page, defaultValue?: T): any;
    deleteState(key: keyof Page): void;
    clearInitialState(key: keyof Page): void;
    browserHasHistoryEntry(): boolean;
    clear(): void;
    setCurrent(page: Page): void;
    isValidState(state: any): boolean;
    getAllState(): Page;
}
export declare const history: History;
export {};
