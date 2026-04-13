/**
 * SSR Error Classification for Production Server
 *
 * This module detects common SSR errors and provides helpful hints
 * to developers on how to fix them.
 */
export type SSRErrorType = 'browser-api' | 'component-resolution' | 'render' | 'unknown';
type SourceMapResolver = (file: string, line: number, column: number) => {
    file: string;
    line: number;
    column: number;
} | null;
export declare function setSourceMapResolver(resolver: SourceMapResolver | null): void;
export interface ClassifiedSSRError {
    error: string;
    type: SSRErrorType;
    component?: string;
    url?: string;
    browserApi?: string;
    hint: string;
    stack?: string;
    sourceLocation?: string;
    timestamp: string;
}
export declare const BROWSER_APIS: Record<string, string>;
export declare function classifySSRError(error: Error, component?: string, url?: string): ClassifiedSSRError;
export declare function formatConsoleError(classified: ClassifiedSSRError): string;
export {};
