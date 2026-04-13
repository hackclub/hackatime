import { createLayoutPropsStore, mergeLayoutProps } from '@inertiajs/core';
import { getContext } from 'svelte';
import { readable } from 'svelte/store';
const store = createLayoutPropsStore();
export function setLayoutProps(props) {
    store.set(props);
}
export function setLayoutPropsFor(name, props) {
    store.setFor(name, props);
}
export function resetLayoutProps() {
    store.reset();
}
export const LAYOUT_CONTEXT_KEY = Symbol('inertia-layout');
export function useLayoutProps(defaults) {
    const context = getContext(LAYOUT_CONTEXT_KEY);
    const resolve = () => {
        const staticProps = context?.staticProps ?? {};
        const name = context?.name;
        const { shared, named } = store.get();
        const dynamicProps = name ? { ...shared, ...named[name] } : shared;
        return mergeLayoutProps(defaults, staticProps, dynamicProps);
    };
    return readable(resolve(), (set) => store.subscribe(() => set(resolve())));
}
