import { ScrollRegion } from './types';
export declare class Scroll {
    static save(): void;
    static getScrollRegions(): ScrollRegion[];
    protected static regions(): NodeListOf<Element>;
    static scrollToTop(): void;
    static reset(): void;
    static scrollToAnchor(): void;
    static restore(scrollRegions: ScrollRegion[]): void;
    static restoreScrollRegions(scrollRegions: ScrollRegion[]): void;
    static restoreDocument(): void;
    static onScroll(event: Event): void;
    static onWindowScroll(): void;
}
