export declare const getScrollableParent: (element: HTMLElement | null) => HTMLElement | null;
export declare const getElementsInViewportFromCollection: (elements: HTMLElement[], referenceElement?: HTMLElement) => HTMLElement[];
export declare const requestAnimationFrame: (cb: () => void, times?: number) => void;
export declare const getInitialPageFromDOM: <T>(id: string) => T | null;
