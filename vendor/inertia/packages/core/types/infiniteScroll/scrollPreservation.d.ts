/**
 * When loading content "before" the current viewport (e.g. loading page 1 when viewing page 2),
 * new content is prepended to the DOM, which naturally pushes existing content down and
 * disrupts the user's scroll position. This system maintains visual stability by:
 *
 * 1. Capturing a reference element and its position before the update
 * 2. After new content is added, calculating how far that reference element moved
 * 3. Adjusting scroll position to keep the reference element in the same visual location
 */
export declare const useInfiniteScrollPreservation: (options: {
    getScrollableParent: () => HTMLElement | null;
    getItemsElement: () => HTMLElement;
}) => {
    createCallbacks: () => {
        captureScrollPosition: () => void;
        restoreScrollPosition: () => void;
    };
};
