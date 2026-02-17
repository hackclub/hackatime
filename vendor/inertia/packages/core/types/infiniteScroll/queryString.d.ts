/**
 * As users scroll through infinite content, this system updates the URL to reflect
 * which page they're currently viewing. It uses a "most visible page" calculation
 * so that the URL reflects whichever page has the most visible items.
 */
export declare const useInfiniteScrollQueryString: (options: {
    getPageName: () => string;
    getItemsElement: () => HTMLElement;
    shouldPreserveUrl: () => boolean;
}) => {
    onItemIntersected: (itemElement: HTMLElement) => void;
    cancel: () => boolean;
};
