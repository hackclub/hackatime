import { type ReloadOptions } from '@inertiajs/core';
interface Props {
    data?: string | string[];
    params?: ReloadOptions;
    buffer?: number;
    as?: keyof HTMLElementTagNameMap;
    always?: boolean;
    children?: import('svelte').Snippet<[any]>;
    fallback?: import('svelte').Snippet;
}
declare const WhenVisible: import("svelte").Component<Props, {}, "">;
type WhenVisible = ReturnType<typeof WhenVisible>;
export default WhenVisible;
