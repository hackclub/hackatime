import { type Readable } from 'svelte/store';
export declare function setLayoutProps(props: Record<string, unknown>): void;
export declare function setLayoutPropsFor(name: string, props: Record<string, unknown>): void;
export declare function resetLayoutProps(): void;
export declare const LAYOUT_CONTEXT_KEY: unique symbol;
export declare function useLayoutProps<T extends Record<string, unknown>>(defaults: T): Readable<T>;
