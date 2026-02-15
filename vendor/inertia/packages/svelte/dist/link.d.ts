import { type CancelToken, type GlobalEventsMap, type LinkComponentBaseProps, type VisitOptions } from '@inertiajs/core';
import type { ActionReturn } from 'svelte/action';
interface ActionElement extends HTMLElement {
    href?: string;
}
type ActionParameters = Omit<LinkComponentBaseProps, 'onCancelToken'> & Omit<VisitOptions, keyof LinkComponentBaseProps>;
type SelectedEventKeys = 'start' | 'progress' | 'finish' | 'before' | 'cancel' | 'success' | 'error' | 'prefetching' | 'prefetched';
type SelectedGlobalEventsMap = Pick<GlobalEventsMap, SelectedEventKeys>;
type ActionAttributes = {
    [K in keyof SelectedGlobalEventsMap as `on:${K}` | `on${K}`]?: (event: CustomEvent<SelectedGlobalEventsMap[K]['details']>) => void;
} & {
    'on:cancel-token'?: (event: CustomEvent<CancelToken>) => void;
    oncanceltoken?: (event: CustomEvent<CancelToken>) => void;
};
declare function link(node: ActionElement, initialParams?: ActionParameters): ActionReturn<ActionParameters, ActionAttributes>;
export default link;
