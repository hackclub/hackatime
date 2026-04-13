type IntersectionObserverCallback = (entry: IntersectionObserverEntry) => void;
interface IntersectionObserverManager {
    new: (callback: IntersectionObserverCallback, options?: IntersectionObserverInit) => IntersectionObserver;
    flushAll: () => void;
}
export declare const useIntersectionObservers: () => IntersectionObserverManager;
export {};
