import { UseInfiniteScrollElementManager } from '../types';
export declare const getPageFromElement: (element: HTMLElement) => string | undefined;
export declare const useInfiniteScrollElementManager: (options: {
    shouldFetchNext: () => boolean;
    shouldFetchPrevious: () => boolean;
    getTriggerMargin: () => number;
    getStartElement: () => HTMLElement;
    getEndElement: () => HTMLElement;
    getItemsElement: () => HTMLElement;
    getScrollableParent: () => HTMLElement | null;
    onPreviousTriggered: () => void;
    onNextTriggered: () => void;
    onItemIntersected: (element: HTMLElement) => void;
    getPropName: () => string;
}) => UseInfiniteScrollElementManager;
