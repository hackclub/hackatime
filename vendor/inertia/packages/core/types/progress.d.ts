declare class Progress {
    hideCount: number;
    start(): void;
    reveal(force?: boolean): void;
    hide(): void;
    set(status: number): void;
    finish(): void;
    reset(): void;
    remove(): void;
    isStarted(): boolean;
    getStatus(): number | null;
}
export declare const progress: Progress;
export default function setupProgress({ delay, color, includeCSS, showSpinner, }?: {
    delay?: number | undefined;
    color?: string | undefined;
    includeCSS?: boolean | undefined;
    showSpinner?: boolean | undefined;
}): void;
export {};
