interface Props {
    data: string | string[];
    fallback?: import('svelte').Snippet;
    children?: import('svelte').Snippet<[{
        reloading: boolean;
    }]>;
}
declare const Deferred: import("svelte").Component<Props, {}, "">;
type Deferred = ReturnType<typeof Deferred>;
export default Deferred;
