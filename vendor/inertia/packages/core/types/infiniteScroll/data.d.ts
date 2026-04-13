import { UseInfiniteScrollDataManager } from '../types';
export declare const useInfiniteScrollData: (options: {
    getPropName: () => string;
    onBeforeUpdate: () => void;
    onBeforePreviousRequest: () => void;
    onBeforeNextRequest: () => void;
    onCompletePreviousRequest: (loadedPage: string | number | null) => void;
    onCompleteNextRequest: (loadedPage: string | number | null) => void;
    onReset?: () => void;
}) => UseInfiniteScrollDataManager;
