export interface LayoutDefinition<Component> {
    component: Component;
    props: Record<string, unknown>;
    name?: string;
}
export interface LayoutPropsStore {
    set(props: Record<string, unknown>): void;
    setFor(name: string, props: Record<string, unknown>): void;
    get(): {
        shared: Record<string, unknown>;
        named: Record<string, Record<string, unknown>>;
    };
    reset(): void;
    subscribe(callback: () => void): () => void;
}
export declare function createLayoutPropsStore(): LayoutPropsStore;
/**
 * Merges layout props from three sources with priority: dynamic > static > defaults.
 * Only keys present in `defaults` are included in the result.
 *
 * @example
 * ```ts
 * mergeLayoutProps(
 *   { title: 'Default', showSidebar: true },  // defaults declared in useLayoutProps()
 *   { title: 'My Page', color: 'blue' },       // static props from layout definition
 *   { showSidebar: false, fontSize: 16 },       // dynamic props from setLayoutProps()
 * )
 * // => { title: 'My Page', showSidebar: false }
 * // 'color' and 'fontSize' are excluded because they're not declared in defaults
 * ```
 */
export declare function mergeLayoutProps<T extends Record<string, unknown>>(defaults: T, staticProps: Record<string, unknown>, dynamicProps: Record<string, unknown>): T;
type ComponentCheck<T> = (value: unknown) => value is T;
/**
 * Normalizes layout definitions into a consistent structure.
 */
export declare function normalizeLayouts<T>(layout: unknown, isComponent: ComponentCheck<T>, isRenderFunction?: (value: unknown) => boolean): LayoutDefinition<T>[];
export {};
